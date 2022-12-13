# The latest image could be used
FROM kong/deck:v1.16.1

# Install a bash interpreter
USER root
RUN apk --no-cache add bash

# Go back to default user for deck
USER deckuser
RUN /bin/bash
# Copy our scripts over for syncing
COPY ./scripts /tmp/scripts
WORKDIR /tmp/scripts
ENTRYPOINT ["/bin/bash"]
# We should always have the startup script available
CMD ["startup.sh"]