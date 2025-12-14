FROM openjdk:11-jre-slim

WORKDIR /graphhopper

# Installa dipendenze e scarica GraphHopper
RUN apt-get update && apt-get install -y wget unzip curl && rm -rf /var/lib/apt/lists/* \
    && wget https://repo1.maven.org/maven2/com/graphhopper/graphhopper-web/8.0/graphhopper-web-8.0.jar -O graphhopper.jar

# Crea la directory per i dati e copia i modelli custom
RUN mkdir -p /data
COPY custom_models/ /graphhopper/custom_models/