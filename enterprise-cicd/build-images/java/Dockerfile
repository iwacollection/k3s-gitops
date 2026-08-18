FROM eclipse-temurin:21-jdk

ARG MAVEN_VERSION=3.9.16

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl git jq tar \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSLO "https://dlcdn.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
    && curl -fsSLO "https://dlcdn.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz.sha512" \
    && echo "$(cat apache-maven-${MAVEN_VERSION}-bin.tar.gz.sha512)  apache-maven-${MAVEN_VERSION}-bin.tar.gz" | sha512sum -c - \
    && tar -xzf "apache-maven-${MAVEN_VERSION}-bin.tar.gz" -C /opt \
    && ln -s "/opt/apache-maven-${MAVEN_VERSION}" /opt/maven \
    && rm "apache-maven-${MAVEN_VERSION}-bin.tar.gz" "apache-maven-${MAVEN_VERSION}-bin.tar.gz.sha512"

ENV MAVEN_HOME=/opt/maven \
    PATH=/opt/maven/bin:$PATH \
    MAVEN_OPTS="-Dmaven.repo.local=/platform-cache/m2"

WORKDIR /workspace

RUN java -version && mvn -version
