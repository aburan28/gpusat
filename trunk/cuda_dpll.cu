#include <stdio.h>
#include <stdlib.h>
#include <cuda.h>
#include <cutil.h>
#include <cuda_runtime_api.h>
#include <sm_11_atomic_functions.h>
#include <sm_12_atomic_functions.h>

#define BUFF_SZ 255

#define NUM_BLOCK 16
#define NUM_THREADS 32

#define MAX_ASSIGN_SIZE 4096

char* partial_assign_cpu;
short* problem_cpu;				 // set of clauses
char* partial_assign_cuda;
short* problem_cuda;
int* flag_gpu ;
int* flag_cpu ;
unsigned int* result_gpu;
unsigned int* result_cpu;
//forward declarations
__host__ int numSat();
__host__ bool dpll_hlpr(unsigned int depth);
__host__ bool dpll();
__host__ bool cuda_dpll_hlpr(unsigned int depth);
__host__ bool cuda_dpll();

unsigned int nbclauses;
unsigned int nbvar;

__global__ void cuda_sat_eval (char* partial_assign, unsigned int num_clauses ,short* problem, unsigned int assign_size, int* flag_gpu , unsigned int* result_gpu)
{

	unsigned char v1,v2,v3;
	__shared__ unsigned short passign[MAX_ASSIGN_SIZE];
	int myid=blockIdx.x*NUM_THREADS+threadIdx.x;

	//copy from global partial assign to shared

	int blocksize=assign_size/NUM_THREADS+1;

	for(int i=1;i<=blocksize;i++)
	{
		if((threadIdx.x*blocksize+i) < assign_size)
		{
			passign[threadIdx.x*blocksize+i]=partial_assign[threadIdx.x*blocksize+i];
//			printf(" partial assign index %d , cpu data %d , gpu data %d \n", threadIdx.x*blocksize+i, partial_assign[threadIdx.x*blocksize+i], passign[threadIdx.x*blocksize+i]);
		}
	}
	__syncthreads();
	//iterate over problem blocked by thread.
	//each thread handles a few clauses
	int clauses_per_thread = num_clauses/(NUM_BLOCK*NUM_THREADS);

	__shared__ unsigned int clause_count[NUM_THREADS];

	clause_count[threadIdx.x] = 0 ;
	
	for(int ii=myid;ii<num_clauses;ii+=NUM_THREADS*NUM_BLOCK)
	{
		v1=(passign[abs(problem[3*ii])]^((problem[3*ii]>>(15))&1));
		v2=(passign[abs(problem[3*ii+1])]^((problem[3*ii+1]>>(15))&1));
		v3=(passign[abs(problem[3*ii+2])]^((problem[3*ii+2]>>(15))&1));

		if((v1|v2|v3)==0)
		{
			clause_count[threadIdx.x]= 0;
//			printf("v1 %d v2 %d v3 %d\n",v1,v2,v3);
//			printf("a1 %d a2 %d a3 %d\n",passign[abs(problem[3*ii])], passign[abs(problem[3*ii+1])], passign[abs(problem[3*ii+2])]);
//			printf("p1 %d p2 %d p3 %d\n",problem[3*ii],problem[3*ii+1],problem[3*ii+2]);
			*flag_gpu = -1;		 //unsatisfiable with this partial assignment
		}
		else if(v1==1||v2==1||v3==1)
		{
			clause_count[threadIdx.x] += 1;

		}
	}

	__syncthreads();
/*
	if(threadIdx.x == 0)
	{
		printf("\n Clause Count Values \n");
		for (int tempint = 0 ; tempint < NUM_THREADS ; tempint ++)
		{
			printf ("index  %d , Value %d \n", tempint , clause_count[tempint]);
		}
	}
*/
//	printf ("Reduction\n");
	for (int k=(NUM_THREADS/2); k>0; k=k>>1)
	{
		if (threadIdx.x < k)
		{
			clause_count[threadIdx.x] += clause_count[ threadIdx.x + k ];
		//	printf("%d = %d + %d \n" , threadIdx.x , threadIdx.x , threadIdx.x + k);
		}
	__syncthreads();
	}
	__syncthreads();

	if(threadIdx.x == 0)
	{
//		printf(" Hi I am block %d , and my count is %d \n ", blockIdx.x , clause_count[0]);
		atomicAdd(result_gpu,clause_count[0]);
	}

}


__host__ void compareFail()
{
	//debug prinfs here
	printf("numsat for cuda and cpu differed\n");
	exit(1);
}


__host__ bool dpll_hlpr(unsigned int depth)
{
	int mynumsat;

	partial_assign_cpu[depth]=1;

	mynumsat=numSat();

	//printf("depth %d val %d numsat %d\n", depth, partial_assign_cpu[depth], mynumsat);

	if(mynumsat==nbvar)
		return true;

	if(mynumsat!=-1)
	{
		if(dpll_hlpr(depth+1))
			return true;
	}

	partial_assign_cpu[depth]=0;

	mynumsat=numSat();

	//printf("depth %d val %d numsat %d\n", depth, partial_assign_cpu[depth], mynumsat);

	if(mynumsat==nbvar)
		return true;

	if(mynumsat!=-1)
	{
		if(dpll_hlpr(depth+1))
			return true;
	}

	partial_assign_cpu[depth]=2;
	return false;

}


__host__ bool test_cuda_dpll_hlpr(unsigned int depth)
{
	int mynumsat,mynumsat2;

	partial_assign_cpu[depth]=1;

	mynumsat=numSat();
	// Cuda Kernel Call
	cudaMemcpy(partial_assign_cuda+sizeof(char), partial_assign_cpu+sizeof(char), nbvar*sizeof(char), cudaMemcpyHostToDevice);
	cudaMemset(result_gpu, 0 ,sizeof(int));
	cudaMemset(flag_gpu, 0 ,sizeof(int));

	cuda_sat_eval<<<NUM_BLOCK,NUM_THREADS>>>(partial_assign_cuda, nbclauses , problem_cuda, nbvar+1, flag_gpu, result_gpu);

	cudaMemcpy(result_cpu,result_gpu, sizeof(unsigned int), cudaMemcpyDeviceToHost);
	cudaMemcpy(flag_cpu, flag_gpu, sizeof(int),cudaMemcpyDeviceToHost);

	if(*flag_cpu == -1)
		mynumsat2 = -1;
	else
		mynumsat2 = *result_cpu;

	printf("depth %d val %d numsat %d\n", depth, partial_assign_cpu[depth], mynumsat);
	if(mynumsat!=mynumsat2)
	{
		printf("cpu numsat %d, gpu numsat %d\n",mynumsat,mynumsat2);
		compareFail();
	}

	if(mynumsat==nbvar)
		return true;

	if(mynumsat!=-1)
	{
		if(test_cuda_dpll_hlpr(depth+1))
			return true;
	}

	partial_assign_cpu[depth]=0;

	mynumsat=numSat();
	// Cuda Kernel Call
	cudaMemcpy(partial_assign_cuda+sizeof(char), partial_assign_cpu+sizeof(char), nbvar*sizeof(char), cudaMemcpyHostToDevice);
	cudaMemset(result_gpu, 0 ,sizeof(int));
	cudaMemset(flag_gpu, 0 ,sizeof(int));
	cuda_sat_eval<<<NUM_BLOCK,NUM_THREADS>>>(partial_assign_cuda, nbclauses , problem_cuda, nbvar+1, flag_gpu, result_gpu  );

	cudaMemcpy(result_cpu,result_gpu, sizeof(unsigned int),cudaMemcpyDeviceToHost);
	cudaMemcpy(flag_cpu, flag_gpu, sizeof(int),cudaMemcpyDeviceToHost);

	if(*flag_cpu == -1)
		mynumsat2 = -1;
	else
		mynumsat2 = *result_cpu;

	printf("depth %d val %d numsat %d\n", depth, partial_assign_cpu[depth], mynumsat);
	if(mynumsat!=mynumsat2)
	{
		printf("cpu numsat %d, gpu numsat %d\n",mynumsat,mynumsat2);
		compareFail();
	}

	if(mynumsat==nbvar)
		return true;

	if(mynumsat!=-1)
	{
		if(test_cuda_dpll_hlpr(depth+1))
			return true;
	}

	partial_assign_cpu[depth]=2;

	return false;

}


__host__ bool cuda_dpll_hlpr(unsigned int depth)
{
	int mynumsat;

	partial_assign_cpu[depth]=1;

	// Cuda Kernel Call
	cudaMemcpy(partial_assign_cuda+sizeof(char), partial_assign_cpu+sizeof(char), nbvar*sizeof(char), cudaMemcpyHostToDevice);
	cudaMemset(result_gpu, 0 ,sizeof(int));
	cudaMemset(flag_gpu, 0 ,sizeof(int));

	cuda_sat_eval<<<NUM_BLOCK,NUM_THREADS>>>(partial_assign_cuda, nbclauses , problem_cuda, nbvar+1, flag_gpu, result_gpu);

	cudaMemcpy(result_cpu,result_gpu, sizeof(unsigned int), cudaMemcpyDeviceToHost);
	cudaMemcpy(flag_cpu, flag_gpu, sizeof(int),cudaMemcpyDeviceToHost);

	if(*flag_cpu == -1)
		mynumsat = -1;
	else
		mynumsat = *result_cpu;


	if(mynumsat==nbvar)
		return true;

	if(mynumsat!=-1)
	{
		if(cuda_dpll_hlpr(depth+1))
			return true;
	}

	partial_assign_cpu[depth]=0;

	// Cuda Kernel Call
	cudaMemcpy(partial_assign_cuda+sizeof(char), partial_assign_cpu+sizeof(char), nbvar*sizeof(char), cudaMemcpyHostToDevice);
	cudaMemset(result_gpu, 0 ,sizeof(int));
	cudaMemset(flag_gpu, 0 ,sizeof(int));
	cuda_sat_eval<<<NUM_BLOCK,NUM_THREADS>>>(partial_assign_cuda, nbclauses , problem_cuda, nbvar+1, flag_gpu, result_gpu  );

	cudaMemcpy(result_cpu,result_gpu, sizeof(unsigned int),cudaMemcpyDeviceToHost);
	cudaMemcpy(flag_cpu, flag_gpu, sizeof(int),cudaMemcpyDeviceToHost);

	if(*flag_cpu == -1)
		mynumsat = -1;
	else
		mynumsat = *result_cpu;

	if(mynumsat==nbvar)
		return true;

	if(mynumsat!=-1)
	{
		if(cuda_dpll_hlpr(depth+1))
			return true;
	}

	partial_assign_cpu[depth]=2;

	return false;

}


__host__ bool cuda_dpll()
{
	bool rval;

	partial_assign_cpu = (char*)malloc((nbvar+1)*sizeof(char));
	memset(partial_assign_cpu, 2, nbvar);

	cudaMalloc((void **) &partial_assign_cuda ,(nbvar+1)*sizeof(char));
	//cudaMemset(partial_assign_cuda, 2 ,nbvar); no need to memset, we copy every time

	printf("functionality test of cuda dpll -- NOT FOR TIMING\n");
	rval = test_cuda_dpll_hlpr(1);
	cudaFree(partial_assign_cuda);
	free(partial_assign_cpu);

	return rval;
}


__host__ bool dpll()
{
	bool rval;

	partial_assign_cpu = (char*)malloc((nbvar+1)*sizeof(char));
	memset(partial_assign_cpu, 2, nbvar);

	rval = dpll_hlpr(1);
	cudaFree(partial_assign_cuda);
	free(partial_assign_cpu);

	return rval;
}


__host__ int numSat()
{
	unsigned int ii;
	unsigned int clause_count=0;
	unsigned char v1,v2,v3;

	for(ii=0;ii<nbclauses;ii++)
	{
		v1=(partial_assign_cpu[abs(problem_cpu[3*ii])]^((problem_cpu[3*ii]>>(15))&1));
		v2=(partial_assign_cpu[abs(problem_cpu[3*ii+1])]^((problem_cpu[3*ii+1]>>(15))&1));
		v3=(partial_assign_cpu[abs(problem_cpu[3*ii+2])]^((problem_cpu[3*ii+2]>>(15))&1));

		if((v1|v2|v3)==0)
			return -1;			 //unsatisfiable with this partial assignment
		else if(v1==1||v2==1||v3==1)
			clause_count++;
	}
	return clause_count;
}


int main(int argc, char** argv)
{

	char buff[BUFF_SZ];
	char linestart;
	unsigned int clause, ii;
	bool error;
	int read;

	memset(buff, '\0', BUFF_SZ);

	printf("c Parsing input\n");

	error=(EOF==scanf("%c%s%u%u", &linestart, buff, &nbvar, &nbclauses));
	error|=(linestart!='p');
	error|=(0!=strcmp(buff, "cnf"));

	if(error)
	{
		fprintf(stderr, "Cannot parse input file\n");
		exit(1);
	}

	problem_cpu = (short *)malloc(3*nbclauses*sizeof(short));
	result_cpu = (unsigned int *)malloc(sizeof(unsigned int));
	flag_cpu = (int *)malloc(sizeof(int));
	if(NULL==problem_cpu)
	{
		fprintf(stderr, "cannot malloc problem_cpu\n");
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
				problem_cpu[ii]=read;
				ii++;
			}

		}while(read!=0);

	}

	printf("c %u vars %u clauses\n", nbvar, nbclauses);
	// Copying the problem into CUDA memory

	cudaMalloc((void **) &problem_cuda ,(3*nbclauses*sizeof(short)+3));
	cudaMalloc((void **) &flag_gpu, (sizeof(int)));
	cudaMalloc((void **) &result_gpu ,(sizeof(unsigned int)));
	cudaMemcpy(problem_cuda, problem_cpu, 3*nbclauses*sizeof(short), cudaMemcpyHostToDevice);

	if(cuda_dpll())
		printf("cpu: SATISFIABLE\n");
	else
	{
		printf("CPU: UNSATISFIABLE\n");
		//	printf("c tested %u of %u possible assignments\n",numtested,1<<nbvar);
	}

	//  Free Cuda memory
	cudaFree(result_gpu);
	cudaFree(problem_cuda);
	return 0;
}
