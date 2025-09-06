## Requirement


To run the code in *nextcloud_docker* directory and so, make the deployment of the cloud system on your local PC or host machine, the user need Docker and Docker Compose. So, please ensure the tools are installed.

*Note* : this code have been defined and tested on a host machine that has Windows as OS. (WSL downloaded)

## Customization

It could be that, conditional on host machine that will be used or personal goal, the user needs to make some personal modification to meet specific requirements. The file to be reviewed are:

* **docker-compose.yaml** for docker container setup
* **docker-compose-performance-test.yaml** for the locust configuration of the test
* **run_test_locust.py** for the loading operations to do


## How to deploy

Firstly, the user needs to clone this GitHub repository. Then, open the terminal and move to the directory where it has saved the repository. Then, 

```bash
cd nextcloud_docker
```

Then, type on terminal the following command:

```bash
docker-compose -f docker-compose.yaml up -d
```

This code will read the service definitions from the manifest, then it will creates and start the defined containers. It will run them in the background. The user should expect an output like this:
```bash
[+] Running 3/3
 ✔ Network nextcloud_docker_nextcloud  Created                                                                                                                                                              0.3s
 ✔ Container nextcloud_docker-db-1   Started                                                                                                                                                              2.3s
 ✔ Container nextcloud_docker-app-1    Started  
```

Once the container are created and up, then the user can access to the instance (here used NextCluoud) by opening a web browser, like Chrome, DuckDuckGo, Mozilla FireFox ... and navigate at http://localhost:8080. 

There, the user will need to login using credentials provided in the manifest. (for admin role, the username is admin and psw is admin too.)



## How to test the service

There are three bash files that allows to create automatically users (simulating their sign in procedures), their trials to upload files and a bash file for cancel from the service the users.

The locust package allows to perform test on the service and see how it behaves with loading operations. To run the test, the user needs to deploy the containers, by running the following command:

```bash
docker-compose -f docker-compose-performance-test.yaml up -d
```
This code will read the service definitions from the manifest, then it will creates and start the defined containers. It will run them in the background. *Note* : the user needs to create the syntethic users before runnign the experiment, using the bash file provided. Also, the user needs to create the 1MB, 1KB and 1GB file.

The expected output should be:

```bash
[+] Running 2/2
 ✔ Container nextcloud_docker-master-1  Started                                                                                                                                                             0.7s
 ✔ Container nextcloud_docker-worker-1  Started   
```

To run the test, open thw web browser at http://localhost:8089 and define the configuration parameters for the simulation in the UI of locust.

Once done everything, if the user want to exit and close everything it has to run either (if only nextcloud up):

```bash
docker compose down
```
or if also locust container are up:

```bash
docker compose down --remove-orphans
```


