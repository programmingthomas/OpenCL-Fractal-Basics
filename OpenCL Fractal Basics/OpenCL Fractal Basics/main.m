// Copyright 2014 Programming Thomas
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <OpenCL/OpenCL.h>

#import "mandelbrot.cl.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        dispatch_queue_t dq = gcl_create_dispatch_queue(CL_DEVICE_TYPE_GPU, NULL);
        if (!dq) {
            fprintf(stdout, "Unable to create a GPU-based dispatch queue.\n");
            exit(1);
        }
        
        //Output size
        size_t width = 1920, height = 1080;
        //Number of iterations to do
        int iter = 1000;
        
        //This actually comes out as an unsigned char *, however we can cast that to an unsigned int * to get four 8-bit channels
        unsigned int * pixels = (unsigned int*)malloc(width * height * sizeof(unsigned int));
        
        cl_image_format format;
        format.image_channel_order = CL_RGBA;
        format.image_channel_data_type = CL_UNSIGNED_INT8;
        
        cl_mem output_image = gcl_create_image(&format, width, height, 1, NULL);
    
        dispatch_sync(dq, ^{
            cl_ndrange range = {
                2,                  // 2 dimensions for image
                {0},                // Start at the beginning of the range
                {width, height},    // Execute width * height work items
                {0}                 // And let OpenCL decide how to divide
                                    // the work items into work-groups.
            };
            
            // Copy the host-side, initial pixel data to the image memory object on
            // the OpenCL device.  Here, we copy the whole image, but you could use
            // the origin and region parameters to specify an offset and sub-region
            // of the image, if you'd like.
            const size_t origin[3] = { 0, 0, 0 };
            const size_t region[3] = { width, height, 1 };
            
            //Execute the kernel
            //mandelbrot_kernel is a GCD block declared in the autogenerated mandelbrot.cl.h file
            mandelbrot_kernel(&range, output_image, (cl_float)width, (cl_float)height, iter);
            
            // Copy back results into pointer
            gcl_copy_image_to_ptr(pixels, output_image, origin, region);
        });
        
        //Finally, export to disk
        NSBitmapImageRep * imageRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:(unsigned char **)&pixels
                                                                              pixelsWide:width
                                                                              pixelsHigh:height
                                                                           bitsPerSample:8
                                                                         samplesPerPixel:4
                                                                                hasAlpha:YES
                                                                                isPlanar:NO
                                                                          colorSpaceName:NSDeviceRGBColorSpace
                                                                            bitmapFormat:NSAlphaNonpremultipliedBitmapFormat
                                                                             bytesPerRow:4 * width
                                                                            bitsPerPixel:32];
        NSData * outData = [imageRep representationUsingType:NSPNGFileType properties:nil];
        [outData writeToFile:[NSHomeDirectory() stringByAppendingPathComponent:@"mandelbrot.png"] atomically:YES];
         
        
        // Clean up device-size allocations.
        // Note that we use the "standard" OpenCL API here.
        clReleaseMemObject(output_image);

        free(pixels);
    }
    return 0;
}
