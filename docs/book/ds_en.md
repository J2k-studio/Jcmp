# Ds (english)

## Counting steps: Big-O
**What it is.** Big-O tells you how the number of steps of a program grows when the data grows. We do not measure time on a clock. We count steps, and we drop small multipliers and small terms. O(n) means the steps grow with the amount of data. O(log n) grows very slowly, because each step cuts the data in half. O(n^2) means two nested loops over the data.
**Why it matters.** Computers differ in speed, but the way the steps grow does not change. With a million rows, an O(n^2) program does about a million million steps, and it will never finish. So choosing the right method matters more than buying a faster computer.
**How to do it.**

Look at how many loops are nested, and how each loop depends on n. One loop that visits every item is O(n). Two loops that visit every pair are O(n^2). A loop that cuts the data in half each time is O(log n).
```jk
#import <stdlib>
using stdlib;

void main() {
    int n = 8;
    int steps = 0;
    for i in 0..n {
        for j in 0..n { steps += 1; }
    }
    jout << steps << "\n";
}
```
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int n = 16;
    for t in 0..3 {
        int linear = n;
        int halving = 0;
        int m = n;
        while m > 1 {
            m = m / 2;
            halving += 1;
        }
        jout << "n " << n << " linear " << linear << " halving " << halving << "\n";
        n = n * 16;
    }
}
```

```
n 16 linear 16 halving 4
n 256 linear 256 halving 8
n 4096 linear 4096 halving 12
```

> **Watch out:** A common mistake is to think that O(n) is only faster than O(n^2) for small data. In fact the gap grows as the data grows. Try larger n and count the steps yourself.
**Exercises**
- One loop that visits every item of n items is which Big-O?
  - a) O(n)  b) O(n^2)  c) O(1)  — Answer: a. One loop runs n times, so its steps grow directly with the amount of data.
- O(log n) grows faster than O(n) when n is large. — Answer: f. O(log n) grows much more slowly, because each step cuts the data in half. O(n) grows directly with n.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int n = 4;
int steps = 0;
for i in 0..n {
    for j in 0..n { steps += 1; }
}
jout << steps << "\n";
}
```
  Output: `16`. Two nested loops that each run n times do n times n steps. That is 16.
- A loop that cuts the data in half each time grows like O(log ___). — Answer: **n**. log n means the logarithm of the amount of data.
- Finding the Big-O of a program: look at how many loops are nested → see what each loop depends on → add up the number of turns → drop the multipliers and small terms. First look at the structure, then count, then drop the parts that do not change the big picture.
- If the data becomes 10 times bigger, how much more work does an O(n^2) program do?
  - a) 100 times  b) 10 times  c) 20 times  — Answer: a. If n becomes 10 times bigger, n times n becomes 100 times bigger.
**Tasks**
- **Count pairs** — Use nested loops over 0..n with n = 8, count every pair (i, j), and print pairs 64. Output: `pairs 64`. Hint: Use two nested loops that both run from 0 to n
- **Count halvings** — Start at 1024. Divide by 2 until you reach 1, count the divisions, and print halvings 10. Output: `halvings 10`. Hint: Use while m > 1 and count each step

## Arrays and lists
**What it is.** An array stores its values next to each other in memory. You can read place i at once, in O(1). But putting a value in the middle means moving the values after it. A list in J2K is an array that grows with push and shrinks with pop, which removes the last value. Adding at the end is fast, on average O(1).
**Why it matters.** Almost every data structure is built on arrays. When you know how much reading, writing and inserting cost in each place, you can choose the right structure for the job.
**How to do it.**

Use int[] list = arr(n), then push to add at the end, pop to remove the last value, and list.len for the number of values.
```jk
#import <stdlib>
using stdlib;

void main() {
    int[] list = arr(4);
    list.push(10);
    list.push(20);
    list.pop();
    jout << list.len << "\n";
}
```
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int[] list = arr(4);
    for i in 1..6 { list.push(i * i); }
    jout << "len " << list.len << "\n";
    jout << "first " << list[0] << " last " << list[list.len - 1] << "\n";
    list.pop();
    jout << "after pop " << list.len << "\n";
}
```

```
len 5
first 1 last 25
after pop 4
```

> **Watch out:** Reading a place past the end, such as list[list.len], does not work, because the last place is len - 1. Build with -d while you learn, so that the compiler checks the index while the program runs.
**Exercises**
- How long does it take to read place i of an array?
  - a) O(1)  b) O(n)  c) O(n^2)  — Answer: a. An array finds the place from i directly, so it does not walk through the data.
- Inserting a value in the middle of an array does not move any other value. — Answer: f. All the values after the insert place must move one place to the right.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int[] a = arr(2);
a.push(3);
a.push(4);
a.pop();
jout << a.len << "\n";
}
```
  Output: `1`. Two pushes add two values. One pop removes one, so one value is left.
- The method that adds a value at the end of a list in J2K is ___. — Answer: **push**. push adds the value at the end.
- Adding three values and then removing the last one: make an empty arr → push the first, second and third value → pop once → check that len is 2. You must add before you can remove, and len shows how many values are left.
- Why is inserting at the front of an array slower than pushing at the end?
  - a) Because every value must move one place to the right first  b) Because push works at the front  c) Because arrays do not take values  — Answer: a. Inserting at the front moves every value, which is O(n). Push at the end is O(1) on average.
**Tasks**
- **Length** — Create a list with arr, push five values, and print len 5. Output: `len 5`. Hint: Use list.len
- **Sum after pop** — Push the values 1 to 5, pop once, and print the sum of the values that are left as sum 10. Output: `sum 10`. Hint: Add all the values left after the pop in a loop

## Stack
**What it is.** A stack is last in, first out (LIFO). The value that was pushed last is popped first. Both push and pop take O(1) time. Stacks drive function calls and undo buttons.
**Why it matters.** When a program calls functions inside each other, the system remembers where to return with a stack. If you understand the stack, you understand recursion and how to check nested brackets.
**How to do it.**

Keep the stack in an array. push adds at the end, pop removes from the end. Check that the stack is not empty before you pop.
```jk
#import <stdlib>
using stdlib;

void main() {
    int[] st = arr(8);
    st.push(1);
    st.push(2);
    jout << st[st.len - 1] << "\n";
}
```
**Example.**

```jk
#import <stdlib>
using stdlib;

int[] st;

void push(int x) { st.push(x); }

int pop() {
    int x = st[st.len - 1];
    st.pop();
    return x;
}

void main() {
    st = arr(8);
    push(1); push(2); push(3);
    jout << pop() << " " << pop() << "\n";
    push(9);
    jout << pop() << " " << st.len << "\n";
}
```

```
3 2
9 1
```

> **Watch out:** Popping an empty stack gives a wrong value or an error. Always check len == 0 before each pop.
**Exercises**
- If you push 1, 2 and 3, which value comes out first from pop?
  - a) 3  b) 1  c) 2  — Answer: a. A stack is LIFO, so the value added last leaves first.
- A stack gives values out in the order they went in, first in first out. — Answer: f. That is a queue. A stack is last in, first out.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

int[] st;

void main() {
st = arr(4);
st.push(5);
st.push(6);
st.pop();
jout << st[st.len - 1] << "\n";
}
```
  Output: `5`. After pushing 5 and 6 and then popping 6, the top value is 5.
- The rule last in, first ___ is called LIFO. — Answer: **out**. Last in, first out: the value that came in last goes out first.
- Checking that the brackets of ( ) are correct: read the text from left to right → on ( push it → on ) pop and check the match → check that the stack is empty at the end. Every opening bracket needs a matching closing bracket in reverse order.
- What does a stack do for nested function calls?
  - a) It remembers where to return for each call  b) It stores pictures  c) It moves files  — Answer: a. The system keeps the return point of each call in a stack. When a function ends, it returns to the last point saved.
**Tasks**
- **Two pops** — Push 1, 2 and 3, then pop twice and print 3 2. Output: `3 2`. Hint: Call pop twice in one line
- **Brackets** — Check whether the text "(a[b])" has balanced brackets, and print balanced yes. Output: `balanced yes`. Hint: Use a stack for the opening brackets, and pop when you see a closing bracket

## Queue and ring buffer
**What it is.** A queue is first in, first out (FIFO), like people in a line. A ring buffer is a queue kept in an array of fixed size. The head and the tail move forward and wrap around at the end of the array, so no value has to be moved.
**Why it matters.** Real systems use queues everywhere, for keyboard input, network packets and sound. When the queue is full, you must decide whether to wait or drop data. A ring buffer shows clearly what its size is.
**How to do it.**

The place of the next free cell is (head + count) % cap. When you take a value out, head moves forward with % too.
```jk
#import <stdlib>
using stdlib;

void main() {
    int cap = 3;
    int[] buf = arr(cap);
    buf.push(0); buf.push(0); buf.push(0);
    jout << buf.len << "\n";
}
```
**Example.**

```jk
#import <stdlib>
using stdlib;

int[] buf;
int head = 0;
int count = 0;
int cap = 4;

bool enqueue(int x) {
    if count == cap { return false; }
    buf[(head + count) % cap] = x;
    count += 1;
    return true;
}

int dequeue() {
    int x = buf[head];
    head = (head + 1) % cap;
    count -= 1;
    return x;
}

void main() {
    buf = arr(cap);
    for i in 0..cap { buf.push(0); }
    for i in 1..6 { jout << enqueue(i * 10) << " "; }
    jout << "\n";
    jout << dequeue() << " " << dequeue() << "\n";
}
```

```
true true true true false 
10 20
```

> **Watch out:** If the queue is full and you still write into it, you overwrite old data. Always check count == cap before you add.
**Exercises**
- Which order does a queue follow?
  - a) First in, first out  b) Last in, first out  c) Random  — Answer: a. A queue gives values out in the order they came in, like people in a line.
- A ring buffer must move values every time a value is taken out. — Answer: f. A ring buffer moves the head position instead of moving the values.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

int[] buf;
int head = 0;
int cap = 3;

void main() {
buf = arr(cap);
buf.push(1); buf.push(2); buf.push(3);
head = (head + 1) % cap;
jout << buf[head] << "\n";
}
```
  Output: `2`. head moves from 0 to 1, and buf[1] holds 2.
- When a ring buffer reaches the end of its array, head wraps back to ___ using %. — Answer: **zero**. The head goes back to the start when it reaches the capacity.
- Taking one value out of a ring buffer: read the value at head → move head forward with % → lower count → return the value read. You must read before you move the head, or you get the next value.
- What should a full queue do?
  - a) Say it is full and refuse the value  b) Overwrite the old value  c) Delete the whole queue  — Answer: a. Overwriting loses data. Saying it is full tells the caller to wait.
**Tasks**
- **One value** — In a ring buffer of size 3, add 1, 2 and 3, take out the first value and print 1. Output: `1`. Hint: Use the moving head
- **Reuse** — In a ring buffer of size 3, add 1, 2 and 3, take out the first value, add 4, then take out two values and print 2 3. Output: `2 3`. Hint: The free place is reused because of the % by cap

## Hash table
**What it is.** A hash table finds a value from its key in about one step. A hash function turns the key into a place in an array. When two keys get the same place, that is a collision. Open addressing tries the next place. J2K gives you Map<K, V>, which does this work for you.
**Why it matters.** Values that are searched by name, such as users or words in a dictionary, must be found fast. Searching one by one in a big array is too slow. Hash tables are used in databases and in almost every language.
**How to do it.**

Use Map<String, int>, put to store, get to read, and has to check whether a key exists.
```jk
#import <stdlib>
using stdlib;

void main() {
    Map<String, int> ages;
    ages.put("ann", 31);
    if ages.has("ann") { jout << ages.get("ann") << "\n"; }
}
```
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    Map<String, int> ages;
    ages.put("ann", 31);
    ages.put("bob", 25);
    ages.put("ann", 32);
    jout << ages.get("ann") << " " << ages.len << "\n";
    if ages.has("zed") { jout << "zed found\n"; } else { jout << "zed not found\n"; }
}
```

```
32 2
zed not found
```

> **Watch out:** ages.get("zed") gives an error when the key is missing. Call has first whenever the key may not exist.
**Exercises**
- About how many steps does a hash table need to find a value from its key?
  - a) About one step  b) As many as the data  c) Twice as many  — Answer: a. The hash function gives the place directly when there are few collisions.
- A put with the same key adds a second entry. — Answer: f. A Map keeps each key once. A put with the same key writes the new value over the old one.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
Map<String, int> m;
m.put("x", 1);
m.put("x", 7);
jout << m.get("x") << " " << m.len << "\n";
}
```
  Output: `7 1`. The key x is overwritten with 7, and there is still only one key.
- The method that checks whether a key is in a Map is called ___. — Answer: **has**. has gives true or false.
- Using a Map safely: put a key and value → check with has → get the value when it is there → do something else when it is not. You must check before you read, or the program fails when the key is missing.
- Why do collisions make a hash table slower?
  - a) You must try several places before you find the key or an empty place  b) Because keys are multiplied  c) Because data is deleted  — Answer: a. After a collision you walk to the next place. When the table is very full, this takes longer.
**Tasks**
- **Store a value** — Make a Map<String, int>, put "a" 1, put "b" 2 and put "a" 5, then print a 5. Output: `a 5`. Hint: Putting the same key again writes over the old value
- **Count keys** — Put the keys x, y and z, then print keys 3 using the len of the Map. Output: `keys 3`. Hint: Use .len of the Map

## Binary search
**What it is.** Binary search works on a sorted array. Look at the middle. If the value you want is smaller, throw away the right half. If it is larger, throw away the left half. Each step halves the data, so it takes about log n steps.
**Why it matters.** A list of one million items needs only about 20 steps. Checking every item one by one would need up to a million steps. Most sorted data is searched this way.
**How to do it.**

Set lo and hi as the ends, compute mid, and compare. Repeat until you find the value or the range is empty.
```jk
#import <stdlib>
using stdlib;

void main() {
    int[] a = arr(4);
    a.push(1); a.push(3); a.push(5); a.push(7);
    int lo = 0;
    int hi = a.len - 1;
    int mid = (lo + hi) / 2;
    jout << mid << "\n";
}
```
**Example.**

```jk
#import <stdlib>
using stdlib;

int find(int[] a, int x) {
    int lo = 0;
    int hi = a.len - 1;
    while lo <= hi {
        int mid = (lo + hi) / 2;
        if a[mid] == x { return mid; }
        if a[mid] < x { lo = mid + 1; } else { hi = mid - 1; }
    }
    return 0 - 1;
}

void main() {
    int[] a = arr(8);
    for i in 0..8 { a.push(i * 3); }
    jout << find(a, 9) << " " << find(a, 10) << " " << find(a, 21) << "\n";
}
```

```
3 -1 7
```

> **Watch out:** The array must be sorted. If it is not, the answer is wrong, and no message tells you. Also set hi = mid - 1 correctly, or the loop may never end.
**Exercises**
- What must be true before you use binary search?
  - a) The array must be sorted  b) All values must be the same  c) The array must be longer than 100  — Answer: a. If the data is not sorted, choosing the left or right half is wrong.
- Binary search on one million items takes about 20 steps. — Answer: t. log2 of one million is about 20.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int[] a = arr(5);
for i in 0..5 { a.push(i * 2); }
int lo = 0;
int hi = a.len - 1;
int mid = (lo + hi) / 2;
jout << a[mid] << "\n";
}
```
  Output: `4`. The array is 0 2 4 6 8. The middle of places 0 to 4 is place 2, which holds 4.
- The middle of a range is computed as (lo + hi) / ___. — Answer: **two**. Dividing by two gives the middle.
- Finding 9 in a sorted array: set lo and hi → compute mid → if found, return its place → if smaller, cut the left, if larger, cut the right. Repeat until the value is found or the range is empty.
- What does the function return when the value is not there?
  - a) -1  b) 0  c) The last value  — Answer: a. -1 means not found, because a real place is never negative.
**Tasks**
- **Find a value** — In the sorted array 1, 3, 5, 7, 9, 11 find 9 and print its place. Output: `4`. Hint: Use binary search
- **Not found** — Find 4 in the same array and print the result. Output: `-1`. Hint: A missing value must give -1

## Two ways to sort
**What it is.** Insertion sort moves each value to its right place in the part that is already sorted. It takes O(n^2) steps, but it is fast for small data. Merge sort splits the data in halves, sorts each half, and merges them. It always takes O(n log n) steps.
**Why it matters.** Sorting is the base of search and reports. When you understand both methods, you see that the same answer can cost very different amounts of work when the data is big.
**How to do it.**

Insertion sort: take out the value at i, move the bigger values one place to the right, then put the value in the empty place.
```jk
#import <stdlib>
using stdlib;

void main() {
    int[] a = arr(3);
    a.push(3); a.push(1); a.push(2);
    for i in 1..a.len {
        int x = a[i];
        int j = i - 1;
        while j >= 0 && a[j] > x {
            a[j + 1] = a[j];
            j -= 1;
        }
        a[j + 1] = x;
    }
    jout << a[0] << a[1] << a[2] << "\n";
}
```
**Example.**

```jk
#import <stdlib>
using stdlib;

void insertion(int[] a) {
    for i in 1..a.len {
        int x = a[i];
        int j = i - 1;
        while j >= 0 {
            if a[j] <= x { break; }
            a[j + 1] = a[j];
            j -= 1;
        }
        a[j + 1] = x;
    }
}

void main() {
    int[] a = arr(4);
    a.push(5); a.push(2); a.push(4); a.push(1);
    insertion(a);
    for i in 0..a.len { jout << a[i] << "\n"; }
}
```

```
1
2
4
5
```

> **Watch out:** If the loop does not check j >= 0 before reading a[j], it reads place -1 and fails. Always check the edge first.
**Exercises**
- What is the usual cost of insertion sort?
  - a) O(n^2)  b) O(log n)  c) O(1)  — Answer: a. For large data it must compare and move values many times.
- Merge sort takes O(n log n) steps in every case. — Answer: t. Splitting and merging makes the work n log n every time.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int[] a = arr(3);
a.push(3); a.push(1); a.push(2);
for i in 1..a.len {
    int x = a[i];
    int j = i - 1;
    while j >= 0 && a[j] > x {
        a[j + 1] = a[j];
        j -= 1;
    }
    a[j + 1] = x;
}
jout << a[0] << a[1] << a[2] << "\n";
}
```
  Output: `123`. Insertion sort makes the array 1 2 3, and the three values are printed together.
- A sort that splits data in halves and merges them is called merge ___. — Answer: **sort**. Merge sort splits, sorts each half and merges.
- Merge sort: split the array into two halves → sort each half by calling the same function → merge the two sorted halves → the whole array is sorted. Each half must be sorted before the merge can work.
- For a few items, why can insertion sort be faster?
  - a) It needs no extra array and no repeated calls  b) It cannot be called  c) It skips values  — Answer: a. Merge sort needs a temporary array and repeated calls, which cost more for small data.
**Tasks**
- **Insertion** — Sort 4, 2, 5, 1 with insertion sort, and print each value on its own line. Output: `1 / 2 / 4 / 5`. Hint: Use the example in this lesson
- **Third value** — Sort 3, 1, 2 and print the value at place 2. Output: `3`. Hint: After sorting, the largest value is at the end

## Search tree
**What it is.** A binary search tree keeps the smaller keys on the left of a node and the larger keys on the right. Search and insert go down one branch at a time. When the tree is balanced, this takes about log n steps. If you insert sorted values one after another, the tree becomes a line, and it is slow.
**Why it matters.** Data that is inserted and searched all the time, such as an index, suits a search tree. An in-order walk gives the values in sorted order without sorting again.
**How to do it.**

Store the nodes in arrays key, left and right, and use indexes as pointers. To insert, start at the root, go left if the key is smaller and right if it is larger, until you find an empty place.
```jk
#import <stdlib>
using stdlib;

void main() {
    int[] key = arr(2);
    key.push(50); key.push(30);
    int k = 40;
    int cur = 0;
    if k < key[cur] { jout << "left\n"; } else { jout << "right\n"; }
}
```
**Example.**

```jk
#import <stdlib>
using stdlib;

int[] key;
int[] left;
int[] right;

int insert(int root, int k) {
    key.push(k); left.push(0 - 1); right.push(0 - 1);
    int id = key.len - 1;
    if root < 0 { return id; }
    int cur = root;
    while true {
        if k < key[cur] {
            if left[cur] < 0 { left[cur] = id; break; }
            cur = left[cur];
        } else {
            if right[cur] < 0 { right[cur] = id; break; }
            cur = right[cur];
        }
    }
    return root;
}

void inorder(int n) {
    if n < 0 { return; }
    inorder(left[n]);
    jout << key[n] << " ";
    inorder(right[n]);
}

void main() {
    key = arr(8); left = arr(8); right = arr(8);
    int root = 0 - 1;
    int[] data = arr(3);
    data.push(50); data.push(30); data.push(70);
    for i in 0..data.len { root = insert(root, data[i]); }
    inorder(root);
    jout << "\n";
}
```

```
30 50 70
```

> **Watch out:** Inserting sorted values one by one makes the tree a straight line, so searching takes O(n). Real trees rebalance themselves to avoid this.
**Exercises**
- Which values are on the left of a node with the key 10?
  - a) Keys smaller than 10  b) Keys larger than 10  c) All keys  — Answer: a. The rule is: smaller on the left, larger on the right.
- An in-order walk (left, node, right) gives the keys in sorted order. — Answer: t. Left, node, right always gives the keys in increasing order.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int[] a = arr(3);
a.push(10); a.push(20); a.push(30);
jout << a[0] + a[2] << "\n";
}
```
  Output: `40`. The first and last values are 10 and 30, which add to 40.
- Search in a tree always starts at the ___ of the tree. — Answer: **root**. The search starts at the root and goes down.
- Inserting 5 into a tree whose root is 3: start at the root 3 → 5 is larger than 3, so go right → if the place is empty, put 5 there → done. You must follow the rule from the root.
- Why does inserting 1, 2, 3, 4 make the tree slow?
  - a) The tree becomes a straight line  b) Because the numbers are small  c) Because there is no root  — Answer: a. Every new key goes to the right, so the height equals the number of keys.
**Tasks**
- **In-order** — Insert 50, 30 and 70 into a search tree, and print the keys in order on one line separated by spaces. Output: `30 50 70`. Hint: Use inorder, which prints each key and a space
- **Height** — Insert 10, 20 and 30 into a tree and print height 3. Output: `height 3`. Hint: A straight tree of three nodes has height 3

## Heap
**What it is.** A min-heap is a complete tree where each parent is smaller than its children. The smallest value is always at the root. push and pop take O(log n) time. The heap is stored in an array: the children of place i are at 2i+1 and 2i+2.
**Why it matters.** A priority queue must take out the most important item fast. Examples are the next job to run, or the shortest path in a graph. A heap gives the smallest value in log n time every time.
**How to do it.**

push adds the value at the end, then sift up: swap with the parent while it is smaller. pop takes the root out, moves the last value to the root, then sift down: swap with the smaller child until the order is right.
```jk
#import <stdlib>
using stdlib;

void main() {
    int[] h = arr(2);
    h.push(1); h.push(5);
    if h[1] < h[0] { jout << "swap\n"; } else { jout << "keep\n"; }
}
```
**Example.**

```jk
#import <stdlib>
using stdlib;

int[] h;

void push(int x) {
    h.push(x);
    int i = h.len - 1;
    while i > 0 {
        int p = (i - 1) / 2;
        if h[p] <= h[i] { break; }
        int t = h[p]; h[p] = h[i]; h[i] = t;
        i = p;
    }
}

int pop_min() {
    int top = h[0];
    h[0] = h[h.len - 1];
    h.pop();
    int i = 0;
    while true {
        int l = 2 * i + 1;
        int r = 2 * i + 2;
        int m = i;
        if l < h.len && h[l] < h[m] { m = l; }
        if r < h.len && h[r] < h[m] { m = r; }
        if m == i { break; }
        int t = h[m]; h[m] = h[i]; h[i] = t;
        i = m;
    }
    return top;
}

void main() {
    h = arr(8);
    push(5); push(3); push(8); push(1);
    jout << pop_min() << " " << pop_min() << "\n";
}
```

```
1 3
```

> **Watch out:** If you forget the sift down after a pop, the heap is broken and the values come out in the wrong order. Test with values that are not in order.
**Exercises**
- Which value is always at the root of a min-heap?
  - a) The smallest value  b) The largest value  c) The first value pushed  — Answer: a. A min-heap keeps the smallest value at the root.
- A heap keeps all the data sorted, like a sorted array. — Answer: f. A heap keeps only the parent and child rule. It does not keep everything sorted.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int[] h = arr(3);
h.push(2); h.push(7); h.push(4);
jout << h[0] + h[1] + h[2] << "\n";
}
```
  Output: `13`. The sum of all the places is 2 + 7 + 4, which is 13, whatever the order.
- In a heap array, the left child of node i is at place 2 * i + ___. — Answer: **one**. The left child is 2i+1, and the right child is 2i+2.
- Popping the smallest value from a heap: keep the root value → move the last value to the root → make the array one place shorter → sift down until it is a heap again. The heap must be repaired after the last value moves to the root, or the parent and child rule breaks.
- How long does a pop of the smallest value take?
  - a) O(log n)  b) O(1) always  c) O(n^2)  — Answer: a. Sift down follows one path down the tree, and its height is log n.
**Tasks**
- **Small heap** — Push 5, 3, 8 and 1, pop the smallest value twice and print 1 3. Output: `1 3`. Hint: Use push and pop_min as in the example
- **Last values** — Push 9, 4 and 7, pop the smallest three times and print 4 7 9 on one line. Output: `4 7 9`. Hint: Each pop must give the smallest value first

## Graph and BFS
**What it is.** A graph is nodes joined by edges, like roads, friends or links. Breadth-first search (BFS) visits the nodes by their distance from the start, using a queue. So the first time it reaches a node is along a shortest path, measured in edges.
**Why it matters.** Maps, social networks and many planning problems are graphs. BFS answers the question: from here, how many steps do I need to reach that place?
**How to do it.**

Store the graph as lists of neighbours. Start with the start node in a queue. Take nodes out one by one, and add each neighbour that has not been seen yet, with distance one more.
```jk
#import <stdlib>
using stdlib;

void main() {
    int[] dist = arr(2);
    dist.push(0); dist.push(0 - 1);
    int[] queue = arr(2);
    queue.push(0);
    dist[1] = dist[0] + 1;
    queue.push(1);
    jout << dist[1] << " " << queue.len << "\n";
}
```
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int n = 4;
    int[] ea = arr(3); int[] eb = arr(3);
    ea.push(0); eb.push(1); ea.push(1); eb.push(2); ea.push(0); eb.push(3);
    int[] dist = arr(n);
    for v in 0..n { dist.push(0 - 1); }
    int[] queue = arr(n);
    queue.push(0);
    dist[0] = 0;
    int qh = 0;
    while qh < queue.len {
        int v = queue[qh];
        qh += 1;
        for e in 0..ea.len {
            int w = 0 - 1;
            if ea[e] == v { w = eb[e]; }
            if eb[e] == v { w = ea[e]; }
            if w >= 0 && dist[w] < 0 { dist[w] = dist[v] + 1; queue.push(w); }
        }
    }
    for v in 0..n { jout << dist[v] << "\n"; }
}
```

```
0
1
2
1
```

> **Watch out:** BFS needs a queue head counter, not removal from the front of an array. It must also mark nodes as seen. Otherwise it goes round a cycle forever.
**Exercises**
- Which structure does BFS use?
  - a) A queue  b) A stack  c) A heap  — Answer: a. BFS visits level by level, so the first in must be the first out.
- Without marks, BFS loops forever on a graph with a cycle. — Answer: t. Without a seen mark, a node in a cycle is added again and again.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int[] d = arr(3);
d.push(0); d.push(0 - 1); d.push(0 - 1);
d[1] = d[0] + 1;
jout << d[1] << "\n";
}
```
  Output: `1`. The distance of node 1 is the distance of node 0 plus one, which is 1.
- A node that BFS has not reached is often marked with the distance ___. — Answer: **minus**. We use -1 as the sign of not reached.
- The steps of BFS: put the start node in the queue → take the front node out → add its unseen neighbours → repeat until the queue is empty. Each node is added to the queue only once.
- Why does BFS find the shortest path?
  - a) It visits all the nodes at distance 1 before the nodes at distance 2  b) It guesses the answer  c) It looks only at the end node  — Answer: a. The first time a node is reached, it comes from the nearest level.
**Tasks**
- **Distance to node 3** — The edges 0-1, 0-2 and 1-3 connect nodes 0 to 3. Find the distance from 0 to 3 and print dist 2. Output: `dist 2`. Hint: Use BFS as in the example
- **Unreachable** — Edge 0-1 only, and node 2 is alone. Find the distance from 0 to 2 and print dist -1. Output: `dist -1`. Hint: A node that cannot be reached stays at -1

## Graph: depth-first search (DFS)
**What it is.** Depth-first search (DFS) goes down one path as far as it can, then goes back when it is stuck. You can write it with an explicit stack, or with recursive calls. A visited mark stops it from going round in circles. DFS visits the same nodes as BFS, but in a different order.
**Why it matters.** DFS checks for cycles, orders tasks that depend on each other, and finds paths in mazes and games. You must know when to use BFS and when to use DFS.
**How to do it.**

Write a function that marks a node as seen and calls itself on each neighbour not yet seen. To count the reached nodes, add one each time a node is visited.
```jk
#import <stdlib>
using stdlib;

int count = 0;

void visit(int v) {
    count += 1;
    if v < 2 { visit(v + 1); }
}

void main() {
    visit(0);
    jout << count << "\n";
}
```
**Example.**

```jk
#import <stdlib>
using stdlib;

int n = 4;
bool[] seen;
int count = 0;
int[] ea;
int[] eb;

void visit(int v) {
    seen[v] = true;
    count += 1;
    for e in 0..ea.len {
        int w = 0 - 1;
        if ea[e] == v { w = eb[e]; }
        if eb[e] == v { w = ea[e]; }
        if w >= 0 && !seen[w] { visit(w); }
    }
}

void main() {
    seen = arr(n);
    for i in 0..n { seen.push(false); }
    ea = arr(3); eb = arr(3);
    ea.push(0); eb.push(1); ea.push(1); eb.push(2); ea.push(0); eb.push(3);
    visit(0);
    jout << "reached " << count << "\n";
}
```

```
reached 4
```

> **Watch out:** If you forget to mark seen before the recursive call, the function visits the same node again and again without end. A very deep recursion can also fill the stack and crash the program.
**Exercises**
- Which structure does DFS use naturally?
  - a) A stack, or recursive calls  b) A queue  c) A heap  — Answer: a. DFS goes deep first, which matches the stack of recursive calls.
- DFS and BFS always reach the same number of nodes from the start. — Answer: t. Both visit every node connected to the start. Only the order is different.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

int c = 0;

void f(int n) {
if n == 0 { return; }
c += 1;
f(n - 1);
}

void main() {
f(3);
jout << c << "\n";
}
```
  Output: `3`. Each call with n above zero adds one to c. There are three such calls, for n = 3, 2 and 1.
- The mark that stops DFS from visiting a node twice is called ___. — Answer: **visited**. visited records that a node has already been seen.
- DFS from node 0: visit 0 and mark it → choose a neighbour not yet seen → call the function on that neighbour → go back when there is nowhere else to go. The mark must be set before the deeper call starts.
- What goes wrong on a graph with a cycle if DFS has no marks?
  - a) It never ends, or the stack overflows  b) It gets faster  c) Nothing  — Answer: a. The same nodes are visited again and again around the cycle.
**Tasks**
- **Count nodes** — Use DFS on the graph with edges 0-1, 1-2, 0-3 and 4 nodes, then print reached 4. Output: `reached 4`. Hint: Use the example in this lesson
- **Not reached** — Use DFS on the edge 0-1 with 3 nodes, then print reached 2. Output: `reached 2`. Hint: A node with no path from the start is not counted

## Dynamic programming
**What it is.** Dynamic programming (DP) solves problems that are made of smaller problems that repeat. It solves each small problem once, stores the answer in a table, and builds the big answer from the table. There are two styles: top-down with memory, and bottom-up with a table.
**Why it matters.** Plain recursion that does not remember old answers can take exponential time. For example, the simple recursive Fibonacci repeats a lot of work. DP makes the time polynomial.
**How to do it.**

Decide clearly what dp[i] means. Write the formula so that dp[i] uses smaller values, then loop from the start values up to the answer.
```jk
#import <stdlib>
using stdlib;

void main() {
    int[] dp = arr(4);
    dp.push(0); dp.push(1);
    for i in 2..4 { dp.push(dp[i - 1] + dp[i - 2]); }
    jout << dp[3] << "\n";
}
```
**Example.**

```jk
#import <stdlib>
using stdlib;

int fib(int n) {
    if n < 2 { return n; }
    int[] dp = arr(n + 1);
    dp.push(0);
    dp.push(1);
    for i in 2..n + 1 { dp.push(dp[i - 1] + dp[i - 2]); }
    return dp[n];
}

void main() {
    jout << fib(10) << "\n";
    jout << fib(1) << "\n";
    jout << fib(20) << "\n";
}
```

```
55
1
6765
```

> **Watch out:** Forgetting the starting values is a common mistake. dp[0] and dp[1] must be set before the loop starts.
**Exercises**
- What is the main idea of DP?
  - a) Store the answers of smaller problems so they are not worked out again  b) Choose the answer at random  c) Sort the data first  — Answer: a. Storing answers that are already known avoids repeating the same work.
- Plain recursive Fibonacci does not repeat any work. — Answer: f. The function calls the same smaller values again and again.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int a = 0;
int b = 1;
for i in 0..5 {
    int t = a + b;
    a = b;
    b = t;
}
jout << a << "\n";
}
```
  Output: `5`. The sequence 0 1 1 2 3 5 after five turns gives a equal to 5.
- You should make the meaning of dp[i] ___ before you write the formula. — Answer: **clear**. A clear meaning helps you write a correct formula.
- A DP table: define what each table place means → set the start values → write the formula from small to large → read the answer from the last place. Values that a formula needs must be worked out before it.
- Why is memoised Fibonacci faster than plain recursion?
  - a) It does not work out the same smaller problem again  b) It uses a heap  c) It does not use variables  — Answer: a. Remembering the answers means each smaller problem is worked out only once.
**Tasks**
- **Fibonacci** — Use DP to find fib(10) and print fib 55. Output: `fib 55`. Hint: Fill the table from the start values 0 and 1
- **Stairs** — The number of ways to climb 4 stairs with steps of 1 or 2 is 5. Print ways 5. Output: `ways 5`. Hint: ways[n] = ways[n-1] + ways[n-2], starting from 1 and 2
