#!/bin/bash

if ! curl --verbose --header 'Host: localhost' 'http://127.0.0.1/' --output test.out; then
	echo "CHECK FAILED (nginx): Failed to get test Flask app output"
	echo "= = = OUTPUT = = ="
	cat test.out
	echo "= = = OUTPUT = = ="
	false
fi

echo "TEST SUCCESS" > test.out.correct
if ! diff test.out test.out.correct; then
	echo "CHECK FAILED (nginx): Contents of output from Flask does not match what it should be"
	echo "= = = test.out = = ="
	cat test.out
	echo "= = = test.out = = ="
	echo "= = = test.out.correct = = ="
	cat test.out.correct
	echo "= = = test.out.correect = = ="
	false
fi

