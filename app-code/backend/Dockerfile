FROM node

ARG USERNAME=node_user
ARG UID=1001
ARG GID=1001

RUN groupadd -g ${GID} ${USERNAME} && useradd -g ${GID} -u ${UID} -m ${USERNAME}

RUN mkdir /app && chown -R ${USERNAME}:${USERNAME} /app

WORKDIR /app

COPY --chown=${USERNAME}:${USERNAME} package* .
RUN npm install

COPY . .

USER ${USERNAME}

CMD [ "node", "index.js" ]