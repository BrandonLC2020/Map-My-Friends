# The Firestore emulator is a Java process, so a JRE is required alongside
# the Node-based firebase-tools CLI.
FROM node:22-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    default-jre-headless \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g firebase-tools@13

WORKDIR /workspace

EXPOSE 4000 8080 9099

CMD ["firebase", "emulators:start", \
     "--project", "map-my-friends-local", \
     "--only", "auth,firestore"]
