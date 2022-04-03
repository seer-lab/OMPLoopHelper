// openmp-analysis
// pass test
//https://github.com/jaekor91/pcat-prototypes/blob/44e5d35f08106b3c2fc800cb8fdcab70f1af6387/block_hashing_prototype.c

// This file is used to demonstrate how the block hashing---that is, how given
// x, y, blocksize of an object, the program determines to which block the object
// belongs.

// Note: Be careful about the random number generation. This may require more serious thinking. 
// Currently, I am simply using different seed for each thread.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <sys/time.h>
#include <omp.h>
#include <assert.h>
#include <sys/mman.h>

// Define global dimensions
#define AVX_CACHE 16
#define AVX_CACHE2 16
#define NPIX_div2 12
#define INNER 10
#define MARGIN1 0 // Margin width of the block
#define MARGIN2 NPIX_div2 // Half of PSF
#define REGION 8 // Core proposal region 
#define BLOCK (REGION + 2 * (MARGIN1 + MARGIN2))
#define NUM_BLOCKS_PER_DIM 16
#define NUM_BLOCKS_TOTAL (NUM_BLOCKS_PER_DIM * NUM_BLOCKS_PER_DIM)
#define MAXCOUNT 8 // Max number of objects to be "collected" by each thread when computing block id for each object.
#define MAXCOUNT_BLOCK 32 // Maximum number of objects expected to be found in a proposal region.
#define INCREMENT 1 // Block loop increment
#define NITER_BURNIN 10000// Number of burn-in to perform
#define NITER (1000+NITER_BURNIN) // Number of iterations
#define BYTES 4 // Number of byte for int and float.
#define STAR_DENSITY_PER_BLOCK ((int) (0.1 * BLOCK * BLOCK)) 
#define MAX_STARS (STAR_DENSITY_PER_BLOCK * (NUM_BLOCKS_PER_DIM * NUM_BLOCKS_PER_DIM)) // Maximum number of stars to try putting in. // Note that if the size is too big, then segfault will ocurr
#define DATA_WIDTH (NUM_BLOCKS_PER_DIM * BLOCK)
#define IMAGE_WIDTH ((NUM_BLOCKS_PER_DIM+1) * BLOCK) // Extra BLOCK is for padding with haf block on each side
#define IMAGE_SIZE (IMAGE_WIDTH * IMAGE_WIDTH)

// Bit number of objects within 
#define BIT_X 0
#define BIT_Y 1
#define BIT_FLUX 2

#define TRUE_MIN_FLUX 250.0
#define TRUE_ALPHA 2.00

// Some MACRO functions
/* #define max(a,b) \
   ({ __typeof__ (a) _a = (a); \
       __typeof__ (b) _b = (b); \
     _a > _b ? _a : _b; })
#define min(a,b) \
    ({ typeof (a) _a = (a);    \
	typeof (b) _b = (b);   \
        _a < _b ? _a : _b; })   */


int generate_offset(int min, int max)
{
	// Return a random number [min, max)
	int i;
	int diff = max-min;
	if (max>0){
		i = (rand() % diff) + min;
	}
	return i;	
}


int main(int argc, char *argv[])
{	

	// Print basic parameters of the problem.

	// Initialize hashing variables	
	//#pragma omp parallel for simd
	//@omp-analysis=true
	for (int i=0; i<MAXCOUNT * max_num_threads * NUM_BLOCKS_TOTAL; i++){
		OBJS_IN_BLOCK[i] = -1; // Can't set it to zero since 0 is a valid object number.
	}		



	double start, end, dt, dt_per_iter; // For timing purpose.
	// For each number of stars.
	dt = 0; // Time accumulator

	// Initializing random seed for the whole program.
	srand(123);
	int time_seed; // Every time parallel region is entered, reset this seed as below.

	// Start of the loop
	printf("\nLoop starts here.\n");
	for (j=0; j<NITER; j++){

		// ----- Initialize object array ----- //
		//#pragma omp parallel for simd
		//@omp-analysis=true
		for (i=0; i< AVX_CACHE * MAX_STARS; i++){
			OBJS[i] = -1; // Can't set it to zero since 0 is a valid object number.
		}				

		time_seed = (int) (time(NULL)) * rand(); // printf("Time seed %d\n", time_seed);		
        #pragma omp parallel 
        {
			// Initialize objects array
			int p_seed = time_seed * (1+omp_get_thread_num()); // Note that this seeding is necessary
			#pragma omp for
			for (i=0; i<MAX_STARS; i++){
				int idx = i*AVX_CACHE;
				OBJS[idx] = (rand_r(&p_seed) % (IMAGE_WIDTH-BLOCK)) + BLOCK/2; // x
				OBJS[idx+1] = (rand_r(&p_seed) % (IMAGE_WIDTH-BLOCK)) + BLOCK/2; // y
				OBJS[idx+2] = TRUE_MIN_FLUX * 1.1; // flux.
			}
		}

		// ------- Generating offsets ------ //
		// Note that image is padded with BLOCK/2 on every side.
		// The mesh size is the same as the image size. It's shifted in each iteration.
		// Positive offset corresponds to adding offset_X, offset_Y for getting the 
		// relevant DATA and MODEL elements but subtracting when computing the block id.		
		// int offset_X = 0; 
		// int offset_Y = 0; 
		int offset_X = generate_offset(-BLOCK/4, BLOCK/4) * 2;
		int offset_Y = generate_offset(-BLOCK/4, BLOCK/4) * 2;
		// printf("Offset X, Y: %d, %d\n", offset_X, offset_Y);

		
		// ----- Main computation begins here ----- //
		start = omp_get_wtime(); // Timing starts here 		

		// Set the counter to zero
		//#pragma omp parallel for simd
		//@omp-analysis=true
		for (i=0; i < max_num_threads * NUM_BLOCKS_TOTAL; i++){
			BLOCK_COUNT_THREAD[i] = 0;
		}

		// For each block, allocate an array of length MAXCOUNT * numthreads 
		// Within each MAXCOUNT chunk, save the indices found by a particular thread.
		// Determine block id using all the threads.
		// Each thread checks out one obj at a time. 
		// Read in x, y and see if it falls within intended region.
		// If the objects are within the proposal region,
		// then update the corresponding block objs array element. 
		// Otherwise, do nothing.

		#pragma omp parallel //shared(BLOCK_COUNT_THREAD)
		{
			int i;
			int t_id = omp_get_thread_num(); // Get thread number			
			#pragma omp for
			for (i=0; i<MAX_STARS; i++){

				// Get x, y of the object.
				// Offset is for the mesh offset.
				int idx = i*AVX_CACHE;
				int x = floor(OBJS[idx] - offset_X - BLOCK/2);
				int y = floor(OBJS[idx+1] - offset_Y - BLOCK/2);

				int b_idx = x / BLOCK;
				int b_idy = y / BLOCK;
				int x_in_block = x - b_idx * BLOCK;
				int y_in_block = y - b_idy * BLOCK;
				// Check if the object falls in the right region.
				// If yes, update.
				if ((x_in_block >= (MARGIN1+MARGIN2)) &  (y_in_block >= (MARGIN1+MARGIN2)) &
					(x_in_block < (MARGIN1+MARGIN2+REGION)) & (y_in_block < (MARGIN1+MARGIN2+REGION)))
				{
					int b_id = (b_idx * NUM_BLOCKS_PER_DIM) + b_idy; // Compute block id of the object.
					OBJS_IN_BLOCK[MAXCOUNT * (max_num_threads * b_id + t_id) + BLOCK_COUNT_THREAD[b_id + NUM_BLOCKS_TOTAL * t_id]] = i; // Deposit the object number.
					BLOCK_COUNT_THREAD[b_id + NUM_BLOCKS_TOTAL * t_id]+=1; // Update the counts
					// Caculate the block index
					// OBJS_BID[i] = (b_idx * NUM_BLOCKS_PER_DIM) + b_idy;					

					// // For debugging
					// printf("OBJS x/y after cut: %d/%d\n", x, y);								
					// printf("OBJS number: %d\n", i);
					// printf("Block count: %d\n", BLOCK_COUNT_THREAD[b_id + NUM_BLOCKS_TOTAL * t_id]);					
					// printf("b_id x/y: %d, %d\n", b_idx, b_idy);
					// printf("x/y_in_block: %d, %d\n", x_in_block, y_in_block);				
					// printf("OBJS_BID: %d\n\n", b_id);							
				}//	

			}// End of parallel region
		}// End of BID assign parallel region

		// // Debug: How many stars were collected in total?
		// int counter = 0;
		// int i;
		// for (i=0; i<MAXCOUNT * max_num_threads * NUM_BLOCKS_TOTAL; i++){
		// 	if (OBJS_IN_BLOCK[i]>-1){
		// 		// printf("%d\n", OBJS_IN_BLOCK[i]);
		// 		counter++;
		// 	}
		// }
		// printf("\nCounter value: %d\n", counter);


		// ----- Model evaluation, followed by acceptance or rejection. ----- //
		// Iterating through all the blocks.
		// IMPORTANT: X is the row direction and Y is the column direction.
		time_seed = (int) (time(NULL)) * rand();		
		#pragma omp parallel
		{
			int ibx, iby; // Block idx
			// Recall that we only consider the center blocks. That's where the extra 1 come from
			#pragma omp for collapse(2) 
			for (iby=0; iby < NUM_BLOCKS_PER_DIM; iby+=INCREMENT){ // Column direction				
				for (ibx=0; ibx < NUM_BLOCKS_PER_DIM; ibx+=INCREMENT){ // Row direction
					int k, l, m; // private loop variables
					int block_ID = (ibx * NUM_BLOCKS_PER_DIM) + iby; // (0, 0) corresponds to block 0, (0, 1) block 1, etc.
					// printf("Block ID: %3d, (bx, by): %3d, %3d\n", block_ID, ibx, iby); // Used to check whether all the loops are properly addressed.
					int t_id = omp_get_thread_num();

					// ----- Pick objs that lie in the proposal region ----- //
					int p_nobjs=0; // Number of objects within the proposal region of the block
					int p_objs_idx[MAXCOUNT_BLOCK]; // The index of objects within the proposal region of the block
												// Necessary to keep in order to update after the iteration 
												// We anticipate maximum of MAXCOUNT number of objects
					float p_objs[AVX_CACHE * MAXCOUNT_BLOCK]; //Array for the object information.

					// Sift through the relevant regions of OBJS_IN_BLOCK to find objects that belong to the
					// proposal region of the block.
					int start_idx = block_ID * MAXCOUNT * max_num_threads;
					for (k=0; k < (MAXCOUNT * max_num_threads); k++){
						int tmp = OBJS_IN_BLOCK[start_idx+k]; // See if an object is deposited.
						if (tmp>-1){ // if yes, then collect it.
							p_objs_idx[p_nobjs] = tmp;
							p_nobjs++;
							OBJS_IN_BLOCK[start_idx+k] = -1; //This way, the block needs not be reset.
						}
					}

					// Read in object information
					#pragma omp simd collapse(2)
					for (k=0; k<p_nobjs; k++){
						for (l=0; l<AVX_CACHE; l++){
							p_objs[AVX_CACHE*k+l] = OBJS[p_objs_idx[k]*AVX_CACHE+l];
						}
					}

					// // Debug: Looking at objects selected for change. Must mach objects
					// // identified up-stream
					// if (block_ID==60){
					// 	printf("\nThread/Block id: %3d, %3d\n", t_id, block_ID);
					// 	printf("Number of objects in the block: %d\n", p_nobjs);
					// 	printf("(x,y) after accounting for offsets: %d, %d\n", offset_X, offset_Y);
					// 	for (k=0; k<p_nobjs; k++){
					// 		float x = p_objs[AVX_CACHE*k] - BLOCK/2 - offset_X;
					// 		float y = p_objs[AVX_CACHE*k+1] - BLOCK/2 - offset_Y;
					// 		printf("objs %2d: %.1f, %.1f\n", k, x, y);
					// 	}
					// }


					// Gather operation for the current values.
					float current_flux[MAXCOUNT_BLOCK];
					float current_x[MAXCOUNT_BLOCK];
					float current_y[MAXCOUNT_BLOCK];					
					for (k=0; k<p_nobjs; k++){
						current_x[k] = OBJS[p_objs_idx[k]*AVX_CACHE+BIT_X];
						current_y[k] = OBJS[p_objs_idx[k]*AVX_CACHE+BIT_Y];
						current_flux[k] = OBJS[p_objs_idx[k]*AVX_CACHE+BIT_FLUX];
					}

					// ----- Implement perturbation ----- //
					// Draw random numbers to be used. 3 * p_nobjs random normal number for f, x, y.
					int p_seed = time_seed * (1+t_id); // Note that this seeding is necessary					
					float randn[4 * MAXCOUNT_BLOCK]; // 4 since the alogrithm below generates two random numbers at a time
													// I may be generating way more than necessary.
					#pragma omp simd
					for (k=0; k < 2 * MAXCOUNT_BLOCK; k++){
						// Using 
						float u = (rand_r(&p_seed) / (float) RAND_MAX);
						float v = (rand_r(&p_seed) / (float) RAND_MAX);
						float R = sqrt(-2 * log(u));
						float cosv = cos(2 * M_PI * v);
						float sinv = sin(2 * M_PI * v);
						randn[k] = R * cosv;
						randn[k+2*MAXCOUNT_BLOCK] = R * sinv;
						// printf("%.3f, ", randn[k]); // For debugging. 
					}

					// Generate proposed values. 
					// Also compute flux distribution prior factor
					// Note: Proposed fluxes must be above the minimum flux.
					float proposed_flux[MAXCOUNT_BLOCK];
					float proposed_x[MAXCOUNT_BLOCK];
					float proposed_y[MAXCOUNT_BLOCK];

					#pragma omp simd
					for (k=0; k<p_nobjs; k++){
						// Flux
						float df = randn[(BIT_FLUX * MAXCOUNT_BLOCK) + k] * 12.0; // (60./np.sqrt(25.))
						float f0 = current_flux[k];
						float pf1 = f0+df;
						float pf2 = -pf1 + 2*TRUE_MIN_FLUX; // If the proposed flux is below minimum, bounce off. Why this particular form?
						proposed_flux[k] = max(pf1, pf2);
						// Position
						float dpos_rms = 12.0 / max(proposed_flux[k], f0); // dpos_rms = np.float32(60./np.sqrt(25.))/(np.maximum(f0, pf))
						float dx = randn[BIT_X * MAXCOUNT_BLOCK + k] * dpos_rms; // dpos_rms ~ 2 x 12 / 250. Essentially sub-pixel movement.
						float dy = randn[BIT_Y * MAXCOUNT_BLOCK + k] * dpos_rms;
						proposed_x[k] = current_x[k] + dx;
						proposed_y[k] = current_y[k] + dy;
					}

					// If the position is outside the image, bounce it back inside
					for (k=0; k<p_nobjs; k++){
						float px = proposed_x[k];
						float py = proposed_y[k];
						if (px < 0){
							proposed_x[k] *= -1;
						}
						else{
							if (px > IMAGE_WIDTH-1){
								proposed_x[k] = 2 * (IMAGE_WIDTH-1) - px;
							}
						}

						if (py < 0){
							proposed_y[k] *= -1;
						}
						else{
							if (py > IMAGE_WIDTH-1){
								proposed_y[k] = 2 * (IMAGE_WIDTH-1) - px;
							}
						}									
					}// End of x,y bouncing

					float factor = 0; // Prior factor 
					// Propose position changes
					for (k=0; k< p_nobjs; k++){
						factor -= TRUE_MIN_FLUX * log(proposed_flux[k]/current_flux[k]); // Accumulating factor											
					}

					// Compute dX matrix for current and proposed. Incorporate flux changes.
					int current_ix[MAXCOUNT_BLOCK];
					int proposed_ix[MAXCOUNT_BLOCK];
					int current_iy[MAXCOUNT_BLOCK];
					int proposed_iy[MAXCOUNT_BLOCK];					
					#pragma omp simd
					for (k=0; k< p_nobjs; k++){
						// Calculate dx, dy
						current_ix[k] = ceil(proposed_x[k]);
						current_iy[k] = ceil(proposed_y[k]);
						proposed_ix[k] = ceil(current_x[k]);
						proposed_iy[k] = ceil(current_y[k]);
					}					
					
					// For vectorization, compute dX^T [AVX_CACHE2, MAXCOUNT_BLOCK] and transpose to dX [MAXCOUNT, AVX_CACHE2]
					float current_dX_T[AVX_CACHE2 * MAXCOUNT_BLOCK]; 
					float proposed_dX_T[AVX_CACHE2 * MAXCOUNT_BLOCK];

					#pragma omp simd
					for (k=0; k < p_nobjs; k++){
						// Calculate dx, dy						
						float px = proposed_x[k];
						float py = proposed_y[k];
						float cx = current_x[k];
						float cy = current_y[k];
						float dpx = proposed_ix[k]-px;
						float dpy = proposed_iy[k]-py;
						float dcx = current_ix[k]-cx;
						float dcy = current_iy[k]-cy;

						// flux values
						float pf = proposed_flux[k];
						float cf = current_flux[k];

						// Compute dX * f
						current_dX_T[k] = cf; // 1
						proposed_dX_T[k] = pf; //
						// dx
						current_dX_T[MAXCOUNT_BLOCK + k] = dcx * cf; 
						proposed_dX_T[MAXCOUNT_BLOCK + k] = dpx * pf; 
						// dy
						current_dX_T[MAXCOUNT_BLOCK * 2 + k] = dcy * cf;
						proposed_dX_T[MAXCOUNT_BLOCK * 2+ k] = dpy * pf; 
						// dx*dx
						current_dX_T[MAXCOUNT_BLOCK * 3 + k] = dcx * dcx * cf;
						proposed_dX_T[MAXCOUNT_BLOCK * 3+ k] = dpx * dpx * pf; 
						// dx*dy
						current_dX_T[MAXCOUNT_BLOCK * 4 + k] = dcx * dcy * cf;
						proposed_dX_T[MAXCOUNT_BLOCK * 4+ k] = dpx * dpy * pf; 
						// dy*dy
						current_dX_T[MAXCOUNT_BLOCK * 5 + k] = dcy * dcy * cf;
						proposed_dX_T[MAXCOUNT_BLOCK * 5+ k] = dpy * dpy * pf; 
						// dx*dx*dx
						current_dX_T[MAXCOUNT_BLOCK * 6 + k] = dcx * dcx * dcx * cf;
						proposed_dX_T[MAXCOUNT_BLOCK * 6+ k] = dpx * dpx * dpx * pf; 
						// dx*dx*dy
						current_dX_T[MAXCOUNT_BLOCK * 7 + k] = dcx * dcx * dcy * cf;
						proposed_dX_T[MAXCOUNT_BLOCK * 7+ k] = dpx * dpx * dpy * pf; 
						// dx*dy*dy
						current_dX_T[MAXCOUNT_BLOCK * 8 + k] = dcx * dcy * dcy * cf;
						proposed_dX_T[MAXCOUNT_BLOCK * 8+ k] = dpx * dpy * dpy * pf; 
						// dy*dy*dy
						current_dX_T[MAXCOUNT_BLOCK * 9 + k] = dcy * dcy * dcy * cf;
						proposed_dX_T[MAXCOUNT_BLOCK * 9+ k] = dcy * dcy * dcy * pf; 
					}
					
					// Transposing the matrices: dX^T [AVX_CACHE2, MAXCOUNT_BLOCK] to dX [MAXCOUNT, AVX_CACHE2]
					float current_dX[AVX_CACHE2 * MAXCOUNT_BLOCK];
					float proposed_dX[AVX_CACHE2 * MAXCOUNT_BLOCK];
					for (k=0; k<p_nobjs; k++){
						for (l=0; l<INNER; l++){
							current_dX[k*AVX_CACHE2+l] = current_dX_T[MAXCOUNT_BLOCK*l+k];
							proposed_dX[k*AVX_CACHE2+l] = proposed_dX_T[MAXCOUNT_BLOCK*l+k];							
						}
					}
					

				// printf("End of Block %d computation.\n\n", block_ID);
				} // End of y block loop
			} // End of x block loop
			// printf("-------- End of iteration %d --------\n\n", j);
		}// End of OMP parallel section


		end = omp_get_wtime();
		// Update time only if burn in has passed.
		if (j>NITER_BURNIN){
			dt += (end-start);
		}// End compute time.
	} // End of NITER loop

	// Calculatin the time took.
	dt_per_iter = (dt / (NITER-NITER_BURNIN)) * (1e06); // Burn-in	
	// dt_per_iter = (dt / NITER) * (1e06); // Actual	
	printf("Elapsed time per iter (us), t_eff: %.3f, %.3f\n", dt_per_iter, (dt_per_iter/(NUM_BLOCKS_PER_DIM * NUM_BLOCKS_PER_DIM)));
}



