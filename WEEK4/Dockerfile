FROM openjdk:11

WORKDIR /usr/src/myapp

ARG VERSION

COPY ["gs-spring-boot/initial", "./"]

RUN ./mvnw clean package

ENV VERSION=$VERSION
EXPOSE 8081

CMD ["/bin/bash", "-c", "java -jar target/spring-boot-$VERSION-SNAPSHOT.jar"]