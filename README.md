<p align="center">
  <img src="https://user-images.githubusercontent.com/44441475/170471324-f1abdddd-6331-46d3-a0b6-39dc5efd13f7.png">
</p>

[![GITHUB](https://img.shields.io/badge/GitHub-100000?style=for-the-badge&logo=github&logoColor=white)](https://github.com/artuyero)

# pivotool

pivotool in ethical hacking, as expected, is a simple tool written in bash that could help you in the post exploitation phase to pivot to other systems. 

## Description

Pivotool is a tool that does not pretend to revolutionize the post exploitation phase of a penetration test, but it can help you save time and be more organized.

It consists of a single script written in bash, with a few dependencies that are usually installed on any unix-like system (a Go version of the tool with a self-contained binary is in process :) ).

The mode of operation is semi-automatic. It presents a new prompt in which you indicate the actions you want to perform.

I'm sure it will contain a lot of bugs and many opportunities for improvement, efficiency, etc. Please feel free to indicate them in the issues section.

Thanks! :D

## Try the tool with Docker

### Environment description with docker-compose.yml

```docker
version: "3.9"
services:
    attacker:
        hostname: attacker
        build:
            context: .
            dockerfile: ./Dockerfile_Attacker
        stdin_open: true
        container_name: attacker
        restart: always 
        networks:
            internet:
                ipv4_address: 172.16.0.11
        init: true

    http_server:
        image: httpd:2.4
        hostname: http-server
        container_name: http-server
        restart: always
        expose:
            - "80"
        networks:
            internet:
                ipv4_address: 172.16.0.12
            internal_network:
                ipv4_address: 10.11.12.11

    ssh_server:
        build:
            context: .
            dockerfile: ./Dockerfile_SSH
        hostname: ssh-server
        container_name: ssh-server
        restart: always
        environment:
          - PUID=1000
          - PGID=1000
          - TZ=Europe/Madrid
          - PASSWORD_ACCESS=true
          - USER_PASSWORD=password
          - USER_NAME=arturo
        networks:
            internet:
                ipv4_address: 172.16.0.13
            internal_network:
                ipv4_address: 10.11.12.12

    backend:
        build:
            context: .
            dockerfile: ./Dockerfile_SSH
        hostname: backend
        container_name: backend
        restart: always
        environment:
          - PUID=1000
          - PGID=1000
          - TZ=Europe/Madrid
          - PASSWORD_ACCESS=true
        networks:
            internal_network:
                ipv4_address: 10.11.12.13

networks:
    internet:
        name: internet
        ipam:
            config:
                - subnet: 172.16.0.0/24
    internal_network:
        name: internal_network
        ipam:
            config:
                - subnet: 10.11.12.0/24 
```

### Deploy and connect
```sh
docker compose up -d
docker exec -it ssh-server bash
```

![image](https://user-images.githubusercontent.com/44441475/171835892-7cff14f6-fb28-4a64-a289-ef49cd05ebeb.png)

## Screenshoots
### First view
![image](https://user-images.githubusercontent.com/44441475/171836153-67fa5e7a-70d3-417d-9cce-c7de4f23cfc4.png)

### Commands
![image](https://user-images.githubusercontent.com/44441475/170473897-fe55ba50-1eb3-41c3-b154-90a7f3501ea1.png)

### Example
![image](https://user-images.githubusercontent.com/44441475/170481526-878492db-0c7d-4a29-8b90-cf6ebd099351.png)

## License

See the *LICENSE* file.
