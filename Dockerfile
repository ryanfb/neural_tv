FROM samnco/neuraltalk2:latest

COPY x64_64-install.sh /opt/neural-networks/install.sh
RUN chmod a+x /opt/neural-networks/install.sh
