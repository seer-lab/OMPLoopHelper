// openmp-analysis
// pass test
// source: https://github.com/yonatanblum/Parallel-implementation-of-Sequence-Allignment-MPI-openMP/blob/974dc45c3ef65396365eff6ef8a021922c4d0df1/MPI_OpenMP_functions.c



#include "MPI_OpenMP_functions.h"
#include <omp.h>

//Define String groups CONSERVATIVE and SEMI_CONSERVATIVE
#define SIZE_OF_CONSERVATIVE 9
const char* conservative[] = {"NDEQ","NEQK","STA","MILV","QHRK","NHQK","FYW","HY","MILF"};
#define SIZE_OF_SEMI_CONSERVATIVE 11
const char* semiConservative[] = {"SHG","ATV","CSA","SGND","STPA","STNK","NEQHRK","NDEQHK","SNDEQK","HFY","FVLIM"};


const char stars = '*';
const char colons = ':';
const char points = '.';
const char space = ' ';


void read_Seqs_Details_From_File(Seqs_Details *seqs_d) {
	FILE *fp;
	int i;

	fp = fopen(FILE_NAME_INPUT, "r");
	if (!fp) {
		printf("inhere");
		exit(0);
	}

	// #################read weights from file#################
	fscanf(fp, "%lf", &(seqs_d->weights[0]));
	fscanf(fp, "%lf", &(seqs_d->weights[1]));
	fscanf(fp, "%lf", &(seqs_d->weights[2]));
	fscanf(fp, "%lf", &(seqs_d->weights[3]));
	
	// #################read seq1 from file#################
	fscanf(fp, "%s", (seqs_d->seq1));
	
	// #################read (4) seqs from file#################
	fscanf(fp, "%d", &(seqs_d->numberOfSeqs));
	seqs_d->id_Arr = (int*)calloc(seqs_d->numberOfSeqs,sizeof(int)); // id for each seq
	seqs_d->seqs = (char**)malloc(seqs_d->numberOfSeqs * sizeof(char*));

	for(i=0;i<seqs_d->numberOfSeqs;i++)
	{
		seqs_d->id_Arr[i] = i;
		seqs_d->seqs[i] = (char*)malloc(LENGHT_OF_SEQ * sizeof(char));
		fscanf(fp, "%s", (seqs_d->seqs[i]));
	}

	fclose(fp);
}


void compareSeq1Seq2(Seqs_Details* seqs_d,char* seq1, char* seq2,int indexOfSeq2)
{
	int lenghtSeq1 = strlen(seq1);
	int lenghtSeq2 = strlen(seq2);
	int delta = lenghtSeq1 - lenghtSeq2;
	seqs_d->maxWeight = -INFINITY;
	seqs_d->offset = 0;
	seqs_d->mutantSignPosition = 0;
	
	if(delta == 0) // When both seqs in same length - Only compare chars one time offset=0. 
	{
		compare_Seqs_With_Offset(seqs_d, seq1, seq2, delta,0);
	}else // Go over both sequences and compare by changing offset and mutant O(delta*seq2*seq1)
	{
		char * mutant;
		//##########################OpenMP###########################################
		#pragma omp parallel for
        //@omp-analysis=true
		for(int i=0 ;i<strlen(seq2)+1;i++)//all versions of mutants (O(delta*sq2*seq2))
		{
			mutant = seq2;
			if(i != 0)
			{
				mutant = createMutant(mutant,i);//Adding '-' in specific index
			}	
				compare_Seqs_With_Offset(seqs_d,seq1,mutant,delta,i);//Goes through all versions of seq2 with offset modification
		}
	}
	//##### Print result to console#####
	printf("\nNumberOfSeq2 = %d , LenghtOfSeq2 = %d \nMax Weight = %lf , Offset = %d , MutantSignPosition = %d\n",indexOfSeq2,lenghtSeq2,seqs_d->maxWeight,seqs_d->offset,seqs_d->mutantSignPosition);
}

char* createMutant(char* seq,int index)//O(seq2)
{
	//Adding '-' in seq2 in index i
	char* mutant = (char*)calloc((strlen(seq)+1),sizeof(char));
	char ch = '-';
	int i;
	//##########################OpenMP###########################################
	#pragma omp parallel for
    //@omp-analysis=true
	for(i=0;i<strlen(seq)+1;i++)
	{

		if(i == index)
		{
			strncat(mutant,&ch,1);
		}
		 strncat(mutant, &seq[i], 1);

	}
	return mutant;

}

void compare_Seqs_With_Offset(Seqs_Details* seqs_d,char* seq1,char* seq2,int delta,int indexOfMutantSign)
{
	int lenght = strlen(seq2);
	int i,j;
	char* seq3;
	for(i=0;i<delta+1;i++)//Compare between every char from seq1 to seq2 and everytime another offset O(delta*seq2)
	{
		seq3 = (char*)calloc(lenght,sizeof(char));	
		//##########################OpenMP###########################################
		#pragma omp parallel for//parallel computing
        //@omp-analysis=true
		for(j=0;j<lenght;j++)
		{
			if(seq1[i+j] == seq2[j])
			{
				strncat(seq3,&stars,1); //add '*' to seq3
			}else
			{
				if(isColons(seq1[i+j],seq2[j]))
				{
					strncat(seq3,&colons,1); //add ':' to seq3
				}else if(isPoint(seq1[i+j],seq2[j]))
				{
					strncat(seq3,&points,1); //add '.' to seq3
				}else
				{
					strncat(seq3,&space,1); //add ' ' to seq3
				}
			}
		
		}
		//Compute the weights of created in seq3 and save data in seqs_d struct
		sumWeights(seqs_d, seq3,lenght,i,indexOfMutantSign); //O(lenght=seq2)
		
	}

	free(seq3);
}





int isColons(char c1,char c2)//Search if two chars exists in same group of letters and return colons
{
	for(int i=0;i<SIZE_OF_CONSERVATIVE;i++)
	{
		if(strchr(conservative[i],c1) != NULL && strchr(conservative[i],c2) != NULL)
		{
			return 1;
		}
	}
	return 0;
}

int isPoint(char c1,char c2)//Search if two chars exists in same group of letters and return point
{

	for(int i=0;i<SIZE_OF_SEMI_CONSERVATIVE;i++)
	{
		if(strchr(semiConservative[i],c1) != NULL && strchr(semiConservative[i],c2) != NULL)//check if strchr get specific char[]
		{
			return 1;
		}
	}
	return 0;
}

void sumWeights(Seqs_Details* seqs_d,char* seq3, int size,int newOffset,int indexOfMutantSign)
{
	double numOfStars = 0;
	double numOfColons = 0;
	double numOfPoints = 0;
	double numOfSpaces = 0;

	double newMax = 0;
	//##########################OpenMP###########################################
	#pragma omp parallel for
    //@omp-analysis=true
	for(int i = 0;i<size;i++)//Pass all over the seq3 and summarize the number of time that stars/colons/points/space apear
	{
		if(seq3[i] == stars)
		{
			numOfStars++;
		}else if(seq3[i] == colons)
		{
			numOfColons++;
		}else if(seq3[i] == points)
		{
			numOfPoints++;
		}else
		{
			numOfSpaces++;
		}	
	}
	//Compute the sum of weights W(T) = w0*numOfStars - w1*numOfColons - w2*numOfPoints -w3*numOfSpaces
	newMax = seqs_d->weights[0] * numOfStars - seqs_d->weights[1] * numOfColons - seqs_d->weights[2] * numOfPoints - seqs_d->weights[3] * numOfSpaces;

	if(newMax > seqs_d->maxWeight)
	{
		seqs_d->maxWeight = newMax;
		seqs_d->offset = newOffset;
		seqs_d->mutantSignPosition = indexOfMutantSign;
	}
}










