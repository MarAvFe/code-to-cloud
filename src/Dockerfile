FROM golang:1.11-alpine
ADD . /go/src/hello-pong
RUN go install hello-pong

FROM alpine:latest
COPY --from=0 /go/bin/hello-pong .
ENV PORT 8080
CMD ["./hello-pong"]