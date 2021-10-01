FROM python:3.8.12-bullseye

WORKDIR /server

RUN apt-get -y update && \
    apt-get install software-properties-common -y && \
    add-apt-repository ppa:george-edison55/cmake-3.x -y && \
    apt-get install cmake -y

COPY ./gateway/requirements.txt requirements.txt
RUN pip install -r requirements.txt

COPY ./gateway/* .

RUN chmod 777 /server/aws.py

ENTRYPOINT [ "python" ]
CMD [ "/server/aws.py" ]
