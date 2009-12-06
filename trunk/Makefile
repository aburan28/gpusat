CC := gcc
LD := gcc

CFLAGS := -Wall -std=c99

all: dpll

dpll: dpll.o
	$(CC) ./bin/dpll.o -o ./bin/dpll

dpll.o: dpll.c
	$(CC) -c $(CFLAGS) dpll.c -o ./bin/dpll.o
	
	
clean:
	rm ./bin/dpll.o
