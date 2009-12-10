/* DPLL.c
 * Davis-Putnam-Logman-Loveland SAT solver
 * written to be c99
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>				 //for memset, strcmp
#include <sys/time.h>

//timing
struct timeval start, end;

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



void error(){

	
	printf("numsat compare fail\n");
	exit(1);
}

bool dpll_hlpr(unsigned int depth)
{
	int mynumsat;

	partial_assign[depth]=1;

	mynumsat=numSatMath();

	//printf("depth %d val %d numsat %d\n", depth, partial_assign[depth], mynumsat);

	if(mynumsat==nbvar)
		return true;

	if(mynumsat!=-1)
	{
		if(dpll_hlpr(depth+1))
			return true;
	}

	partial_assign[depth]=0;

	mynumsat=numSatMath();

	//printf("depth %d val %d numsat %d\n", depth, partial_assign[depth], mynumsat);

	if(mynumsat==nbvar)
		return true;

	if(mynumsat!=-1)
	{
		if(dpll_hlpr(depth+1))
			return true;
	}

	partial_assign[depth]=2;
	return false;

}


bool dpll()
{
	bool rval;
	partial_assign = malloc((nbvar+1));
	memset(partial_assign, 2, (nbvar+1));///////////////////////////////////////
	rval = dpll_hlpr(1);
	free(partial_assign);
	return rval;
}


int numSatMath()
{
	unsigned int ii;
	unsigned int clause_count=0;
	unsigned char v1,v2,v3;
	
	
	for(ii=0;ii<nbclauses;ii++)
	{
		
		v1=(partial_assign[abs(problem[3*ii])]^((problem[3*ii]>>(15))&1));
		v2=(partial_assign[abs(problem[3*ii+1])]^((problem[3*ii+1]>>(15))&1));
		v3=(partial_assign[abs(problem[3*ii+2])]^((problem[3*ii+2]>>(15))&1));

		if((v1|v2|v3)==0){
			return -1;			 //unsatisfiable with this partial assignment
		}
		else if(v1==1||v2==1||v3==1)
		{
				clause_count++;

		}
	}
	return clause_count;		

}


int numSat()
{
	unsigned int ii,jj,clause_val=0, has_unassigned=0;
	unsigned int clause_count=0;

	for(ii=0;ii<nbclauses;ii++)
	{
		clause_val=0, has_unassigned=0;

		for(jj=0;jj<3;jj++)
		{
			switch(partial_assign[abs(problem[3*ii+jj])])
			{
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
			return -1;			 //unsatisfiable with this partial assignment
		else
			clause_count+=clause_val;
	}
	return clause_count;
}




#define BUFF_SZ 255
int main(int argc, char **argv)
{

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

	if(error)
	{
		fprintf(stderr, "Cannot parse input file\n");
		exit(1);
	}

	problem = malloc(3*nbclauses*sizeof(short));
	if(NULL==problem)
	{
		fprintf(stderr, "cannot malloc problem\n");
		exit(2);
	}

	ii=0;
	for(clause=0; clause<nbclauses; clause++)
	{
		do
		{
			if(EOF==scanf("%d",&read))
			{
				fprintf(stderr, "Cannot parse input file\n");
				exit(1);
			}
			if(read!=0)
			{
				problem[ii]=read;
				ii++;
			}

		}while(read!=0);

	}

	printf("Parsed! starting sat\n");

	gettimeofday(&start, NULL);
	bool val=dpll();
	gettimeofday(&end,NULL);

	if(val)
		printf("SAT!\n");
	else
		printf("UNSAT!\n");
	
	printf( "time %f \n", (((end.tv_sec * 1000000 + end.tv_usec)
			  - (start.tv_sec * 1000000 + start.tv_usec)))/1000.0);

}
