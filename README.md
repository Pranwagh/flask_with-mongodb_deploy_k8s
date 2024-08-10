# flask_with-mongodb_deploy_k8s

Table of Contents
	1. Prerequisites
	2. Write dockerfile and build and push
	3. Setup Minikube
	4. Deploy Flask Application
	5. Create Persistent Volumes and Claims
	6. Deploy MongoDB
	7. Resource Management & Horizontal Pod Autoscaler (HPA)

 1. Prerequisites
	• Minikube installed and running
	• kubectl CLI tool installed
	• Docker installed
	
	2. Dockerfile 
	• Read instruction to build and push Docker image file 

	3. Setup Minikube

		○ minikube start
		

	4. Deploy Flask Application

4.1 Write yml manifest file for flask deployment  , include in it following important components 
	
		○ kind - What kind of object you want to create. i.e Deployment 
		○ metadata - Data that helps uniquely identify the object, including a name string, label. 
		○ Spec.replicas — Tells Kubernetes how many pods to create during a deployment. Modifying this field is an easy way to scale a containerized application. 
		○ spec.selector — tells the Kubernetes deployment controller to only target pods that match the specified labels.  
		○ Docker image:  contained the python flask application on docker hub , 
		○ Env : enviroment variable containing MONGODB-URI to connect to mongo db pods via its service.
			§ mongodb://username:password@mongo db service name :27017/
		○ containerPort : tells port open for communication 

	
Apply the YAML:  
			kubectl apply -f flask-deployment.yaml
			

	kind: Deployment
	metadata:
	  name: flask-deployment       # Name of the deployment
	  labels:
	    app: flasktask                 # Labels for identifying the deployment
	spec:
	  replicas: 2                  # Number of replicas (pods) to deploy
	  selector:
	    matchLabels:
	      app: flasktask               # Selector to match the labels in the pod template
	  template:
	    metadata:
	      labels:
	        app: flasktask             # Labels for the pods created by this deployment
	    spec:
	      containers:
	      - name: flasktask
	        image: pranav8999/flask:1.0    # flask app  image to use
	        env:
	        - name: MONGODB_URI
	          value : "mongodb://admin:admin@mongo:27017/"
	
	        ports:
	        - containerPort: 5000    # Exposing port 5000 of the container
	        resources:
	         requests:
	          cpu: "200m"
	          memory: "250Mi"
	         limits:
	          cpu: "0.5"
	          memory: "500Mi"
	
	---
	
	

4.2  Create a Service for Flask Application:

	Write yml manifest file  , include in it following important components 

	○ kind - service
	○ Services match a set of Pods using labels and selectors. Selector in service must match label  in deployment.
	○ NodePort : It  is possible to contact the NodePort Service, from outside the cluster, by requesting NodeIP : NodePort 

Apply the yaml file
			kubectl apply -f flask-service.yaml
			

	apiVersion: v1
	kind: Service
	metadata:
	  name: flasktask-svc-nodeport
	spec:
	  # Expose the service on a static port on each node
	  # so that we can access the service from outside the cluster
	  type: NodePort
	
	  # When the node receives a request on the static port (30007)
	  selector:
	    app: flasktask
	
	  ports:
	    # Three types of ports for a service
	    # nodePort - a static port assigned on each the node
	    # port - port exposed internally in the cluster
	    # targetPort - the container port to send requests to
	    - nodePort: 30163
	      port: 80
	      targetPort: 5000
	
	
TEST :
After successfully creating flask app pods and service , try to Access pods by
 host ip address : nodeport of service


	5. Create persistent Volume and Persistent Volume Claim


5.1  Create Persistent Volume:

	• Provide storage capacity  , AccessMode  , Hostpath 
	• Design Choices :
		○  here we have various type of AccessMode like ReadOnlyMany (ROX) , ReadWriteMany (RWX)  , ReadWriteOnce (RWO)   
		○ WE gave The ReadWriteOnce (RWO) access mode lets a single node mount the volume as read-write at a time ,As application running on minikube one node.

Apply the YAML :

		Kubectl apply -f mogo-pv.yml
	

	kind: PersistentVolume
	apiVersion: v1
	metadata:
	  name: mongo-pv
	  labels:
	    type: local
	spec:
	  storageClassName: manual
	  capacity:
	    storage: 300Mi
	  accessModes:
	    - ReadWriteOnce
	  hostPath:
	    path: "/mnt/mongo_data"


5.2  Create Persistent Volume Claim:

	• Provide same access mode and storage with Persistent Volume
	
Apply the YAML :

		Kubectl apply -f mogo-pvc.yml


	apiVersion: v1
	kind: PersistentVolumeClaim
	metadata:
	  labels:
	    app: mongo-claim0
	  name: mongo-claim0
	spec:
	  accessModes:
	  - ReadWriteOnce
	  storageClassName: manual
	  resources:
	    requests:
	      storage: 300Mi
	
	6. Deploy MongoDB 

6.1 Create a Secret for MongoDB Credentials:

	• DesignChoices : We can add the Secret data using the data field or the stringData field . In stringData field we directly give data without encoding.
Using the data field, you must encode the secret data using base64.  so I have used data field as to avoid readiblity. 

Kubectl apply -f mongo-secret.yml

	apiVersion: v1
	data:
	  MONGO_USERNAME: YWRtaW4=
	  MONGO_PASSWORD: YWRtaW4=
	kind: Secret
	metadata:
	  name: mongodb-secret
	type: Opaque
	

6.2 Create a StatefulSet for MongoDB:

	
Apply Yaml :

	Kubectl apply -f mongo-statefulset.yml
	


	apiVersion: apps/v1
	kind: StatefulSet
	metadata:
	  labels:
	    app: mongo
	  name: mongo
	spec:
	  serviceName: mongo
	  replicas: 1
	  selector:
	    matchLabels:
	      app: mongo
	  template:
	    metadata:
	      labels:
	        app: mongo
	    spec:
	      containers:
	      - env:
	        - name: USERNAME
	          valueFrom:
	            secretKeyRef:
	              name: mongodb-secret
	              key: MONGO_USERNAME
	        - name: PASSWORD
	          valueFrom:
	            secretKeyRef:
	              name: mongodb-secret
	              key: MONGO_PASSWORD
	        image: mongo
	        imagePullPolicy: ""
	        name: mongo
	        ports:
	        - containerPort: 27017
	        resources:
	         requests:
	          cpu: "200m"
	          memory: "250Mi"
	         limits:
	          cpu: "0.5"
	          memory: "500Mi"
	        volumeMounts:
	        - mountPath: /data/db
	          name: mongo-claim0
	      restartPolicy: Always
	      serviceAccountName: ""
	      volumes:
	      - name: mongo-claim0
	        persistentVolumeClaim:
	          claimName: mongo-claim0

6.3 Create a Service for MongoDB:

	• To ensuring MongoDB is accessible only within the cluster.
		○  clusterIP: None:  the service becomes a headless service, commonly used with StatefulSets. This means that it doesn't assign a Cluster IP, and the service will not act as a load balancer. Instead, each pod will be accessible directly via its DNS name.
		○ enhancing security by limiting its exposure to external threats.
	
Kubectl apply -f mongo-headless-service.yml


	apiVersion: v1
	kind: Service
	metadata:
	  labels:
	    app: mongo
	  name: mongo
	spec:
	  ports:
	  - port: 27017
	    targetPort: 27017
	  clusterIP: None
	  selector:
	    app: mongo
	


Now to connect to Flask app deployment to mongo-db statefulset . 
	• Flask app deployment YAML should specify the correct MongoDB service name in the environment variable. 
	• MongoDB instance requires authentication, Flask application should give it in MONGO_URI .
	• Ensure your Flask application code is reading the MONGO_URI environment variable correctly .



	7. explanation of resource requests and limits in Kubernetes. 

7.1 resource request and limits

I have launched minikube with t4g.small instance type on AWS . It has 
	• vCPUs: 2
	• Memory: 2 GiB memory of node

To know the Allocated memory & CPU 

	• Kubectl describe node  <minkube node name>

metrics-server addon is essential for monitoring and gathering resource usage metrics in a Kubernetes cluster. After enabling it, we can use kubectl top commands to monitor resource usage, such as CPU and memory, for pods and nodes.

	• minikube addons enable metrics-server 
Below command tells how much resoureces like CPU(core) and memory each pods are consuming   , 

	• Kubectl top pods

Sample values of limits and requests (request: 0.2cpu, 250M ; limit: 0.5cpu, 500M) 
So add block of request and limit in flask app yaml and  mongodb  yaml 

		 resources:
		         requests:
		          cpu: "200m"
		          memory: "250Mi"
		         limits:
		          cpu: "0.5"
		          memory: "500Mi"
		


To check if the resource requests and limits for a deployment in Kubernetes :

	• kubectl describe deployment <deployment-name>
This command will show the deployment details, including the container specs where you can verify the CPU and memory requests and limits. 


7.2 Horizontal Pod Autoscaler (HPA):

	• Provide minimum and maximum pods number , threshold CPU utilisation , name of flask app deployment 
Apply Yaml :  

Kubectl apply -f hpa.yml

	
	apiVersion: autoscaling/v2
	kind: HorizontalPodAutoscaler
	metadata:
	  name: flask-deployment
	spec:
	  minReplicas: 2
	  maxReplicas: 5
	  metrics:
	    - resource:
	        name: cpu
	        target:
	          averageUtilization: 70
	          type: Utilization
	      type: Resource
	  scaleTargetRef:
	    apiVersion: apps/v1
	    kind: Deployment
	    name: flask-deployment    


	









































