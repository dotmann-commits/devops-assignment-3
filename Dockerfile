# Lightweight Linux base image
FROM alpine:3.20

# Install only required packages
RUN apk add --no-cache bash coreutils iputils bind-tools

WORKDIR /app

# Copy the application into the image
COPY app/ /app/

# Set executable permissions
RUN chmod +x /app/app.sh

RUN addgroup -S devops && adduser -S devops -G devops
USER devops

ENTRYPOINT ["/app/app.sh"]
CMD ["help"]
