#!/bin/bash
set -e

find . | entr ./convert.sh
