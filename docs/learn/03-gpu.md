# 3. The GPU

A CPU has a few strong cores that each do anything. A **GPU** has hundreds of small cores that do the same instruction on different data at the same time. That suits pictures (every pixel is the same job), and also matrices and neural networks (every number of the result is a sum of products).

## The shape of the work
You write a **kernel**: a small program for one element. The GPU runs it for a million elements, in **groups** (a work group of 16 x 16 threads, for example) that share a fast local memory. The GPU is good at many equal jobs without branches and bad at one long job.

## The cost of the road
The GPU has its own queue. Sending data to it and back takes time (on a phone the memory is shared, so it is cheaper than on a PC, but a copy is still a copy). So the GPU pays off when the job is big: on the Kirin 990 a 256 x 256 matrix product is 1.5 times faster on the GPU and a 512 x 512 one 2.4 times; below 128 the CPU wins.

## In J2K
- `<opengl3>` and `<compute>`: a compute shader in GLSL, buffers that stay on the chip (`bench/gpu_matmul.jk`).
- `<vulkan>`: a device, a queue, buffers shared by the CPU and the GPU, and a compute pipeline from SPIR-V (`VkShaders::vector_add()` adds two arrays on the Mali).
- `<neurongpu>`: `NeuronGpu::enable(16000000)` sends the big products of `<neuron>` to the GPU; the program does not change.

```jk
#import <stdlib>
#import <vulkan>
int main() {
    Vk vk = Vk::open();
    if !vk.ok { jout << vk.log << "\n"; return 1; }
    jout << vk.device_name << ", compute: " << vk.has_compute << "\n";
    vk.close();
    return 0;
}
```
(Build it with `jcmp -dyn` if your compiler asks.)

## Questions
1. A phone screen has 2 million pixels at 60 frames a second. How many kernel runs a second is that?
2. Why is the GPU bad at `if x < 0 {...} else {...}` when half the threads take each side?
3. Run `bench/gpu_matmul.jk` and find the size where the GPU starts to win on your phone.
