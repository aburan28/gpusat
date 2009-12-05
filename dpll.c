/* DPLL.c
 * Davis-Putnam-Logman-Loveland SAT solver
 * written to be c99
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h> //for memset, strcmp
#define bool char
#define true 1
#define false 0

unsigned int nbclauses;
short *problem;
unsigned int nbvar;
char *partial_assign;

//forward declarations
int numSat();
bool dpll_hlpr(unsigned int depth);
bool dpll();

bool dpll_hlpr(unsigned int depth){
	int mynumsat;
	
	partial_assign[depth]=1;


	mynumsat=numSat();
	

	printf("depth %d val %d numsat %d\n", depth, partial_assign[depth], mynumsat);
	
	if(mynumsat==nbvar)
		return true;
	
	if(mynumsat!=-1){
		if(dpll_hlpr(depth+1))
			return true;
	}
	

	partial_assign[depth]=0;

	mynumsat=numSat();

	printf("depth %d val %d numsat %d\n", depth, partial_assign[depth], mynumsat);
	
	if(mynumsat==nbvar)
		return true;
	
	if(mynumsat!=-1){
		if(dpll_hlpr(depth+1))
			return true;
	}
		
	return false;
	
}

bool dpll(){
	bool rval;
	partial_assign = malloc(nbvar*sizeof(short));
	memset(partial_assign, 2, nbvar);
	rval = dpll_hlpr(0);
	free(partial_assign);
	return rval;
}

int numSat(){
	unsigned int ii,jj,clause_val=0, has_unassigned=0;
	unsigned int clause_count=0;
	
	for(ii=0;ii<nbclauses;ii++){	
		clause_val=0, has_unassigned=0;
		
		for(jj=0;jj<3;jj++){
			switch(partial_assign[abs(problem[3*ii+jj])]){
				case 0:
					if(0>problem[3*ii+jj])
						clause_val=1;
					break;
				case 1:
					if(0<problem[3*ii+jj])
						clause_val=1;
					break;
				case 2:
					has_unassigned=1;
					break;
			
			}
		}
		if(0==clause_val && 0==has_unassigned)
			return -1; //unsatisfiable with this partial assignment
		else
			clause_count+=clause_val;
	}
	return clause_count;
}


#define BUFF_SZ 255
int main(int argc, char **argv){
	
	char buff[BUFF_SZ];
	char linestart;
	unsigned int clause, ii;
	bool error;
	int read;
	
	memset(buff, '\0', BUFF_SZ);
	
	printf("Parsing input\n");
	
	error=(EOF==scanf("%c%s%u%u", &linestart, buff, &nbvar, &nbclauses));
	error|=(linestart!='p');
	error|=(0!=strcmp(buff, "cnf"));
	
	if(error){
		fprintf(stderr, "Cannot parse input file\n");
		exit(1);
	}
	
	
	problem = malloc(3*nbclauses*sizeof(short));
	if(NULL==problem){
		fprintf(stderr, "cannot malloc problem\n");
		exit(2);
	}
	
	ii=0;
	for(clause=0; clause<nbclauses; clause++){
		do{
			if(EOF==scanf("%d",&read)){
				fprintf(stderr, "Cannot parse input file\n");	
				exit(1);
			}
			if(read!=0){
				problem[ii]=read;
				ii++;
			}
		
		}while(read!=0);
		
	}
	
	printf("Parsed! starting sat\n");
	
	if(dpll())
		printf("SAT!\n");
	else
		printf("UNSAT!\n");
		
}
	
	

