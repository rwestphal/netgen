#!/bin/sh

sleep 30
for i in $(seq 1 100) ; do netgen-exec rt0 ifconfig rt0-stub0 down && sleep 1 && netgen-exec rt0 ifconfig rt0-stub0 up && sleep 1; done
sleep 30
