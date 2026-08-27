# ============================================================
# Stage 1: Clone + Build + Test
# ============================================================
FROM maven:3.8.6-openjdk-8 AS builder

WORKDIR /app

# Install Git
RUN apt-get update \
    && apt-get install -y git \
    && rm -rf /var/lib/apt/lists/*

# Clone the efficient-webjars branch
RUN git clone \
    --branch efficient-webjars \
    --depth 1 \
    https://github.com/ksnksatwik07/spring-petclinic.git .

# Build and run tests
RUN mvn clean package


# ============================================================
# Stage 2: Runtime
# ============================================================
FROM eclipse-temurin:8-jre

WORKDIR /app

# Copy Spring Boot JAR from build stage
COPY --from=builder /app/target/*.jar app.jar

# Spring Boot port
EXPOSE 8080

# Start application
ENTRYPOINT ["java", "-jar", "app.jar"]