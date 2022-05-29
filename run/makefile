CC = gcc
CFLAGS = -std=c11 \
  -Wall -Wconversion -Werror -Wextra -Wfatal-errors -Wpedantic -Wwrite-strings \
  -O2 -c
LDFLAGS = 
objects = run.o
executable= run

all: $(executable)

clean:
	$(RM) $(executable)

$(executable): $(objects)
	$(CC) $(objects) $(LDFLAGS) -o $(executable)

run.o: run.c