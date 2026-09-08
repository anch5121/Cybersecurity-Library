# syntax=docker/dockerfile:1
FROM dzhang55/cs6264:latest
RUN apt-get update
RUN apt-get install -y vim
RUN apt-get install -y python3-pip
RUN apt-get install -y python3-setuptools
RUN apt-get install -y python-setuptools
RUN apt-get install -y python3-dev libffi-dev build-essential virtualenvwrapper
RUN pip3 install -U pip setuptools 
USER lab1
RUN python3 -m pip install --user ropper
RUN python3 -m pip install angr
RUN python3 -m pip install --user pwntools
RUN python3 -m pip install --user pathlib2
