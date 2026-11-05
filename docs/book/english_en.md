# English (english)

## Read the compiler message
**What it is.** A compiler message has a place and a kind. The place is the file, the line and the column. The kind is error or warning. The words after them tell you what is wrong. The message is written in English, so the short English words are part of the lesson.
**Why it matters.** When a program does not build, the message is your only clue. If you know the short words, you know where to look and what to change, and you do not have to guess.
**How to do it.**

Read the file name and the line number first, then go to that line. Read the word after the place: error means the program is not made; warning means it is made, but something may be wrong. Read the rest of the message word by word, and only then change the code.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    jout << "Read the line number first\n";
}
```

```
Read the line number first
```

> **Watch out:** Many learners read only the first word and stop. Read the place too: the line number tells you exactly where to look.
**Exercises**
- A message says main.jk:5:3: error. What does the word error tell you?
  - a) The file is wrong  b) The program is not made  c) The program is fast  — Answer: b. An error stops the build. A warning does not stop it, so it is the more serious word.
- Which part of the message names the line of the problem?
  - a) The word error  b) The number after the file name  c) The last word  — Answer: b. The file name is followed by the line number and then the column, so 5 in main.jk:5:3 is the line.
- A warning and an error both stop the compiler from making the program. — Answer: f. Only an error stops the build. A warning is a note that something may be wrong.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
jout << "error" << "\n";
}
```
  Output: `error`. A text in double quotes is printed as it is. The quote marks are not printed.
- In main.jk:5:3 the 3 is the ___. — Answer: **column**. The column is the place inside the line. The first character of the line is column 1.
- Read a compiler message: find the file name and the line → read the word error or warning → go to that line → read the rest and change the code. You must know where the problem is and what kind it is before you change anything.
**Tasks**
- **Warning word** — Write a program that prints the word warning and a new line. Output: `warning`. Hint: Use jout with the word in double quotes, and end it with \n.

## Verbs of code
**What it is.** Most lines of code are verbs. Print sends a value out. Store keeps a value under a name. Compare checks two values and gives yes or no. Repeat runs the same lines many times. Learn these five verbs and you can read most short programs.
**Why it matters.** Verbs tell you what the program does. When you read a program in English, first find the verbs, then find the things they act on.
**How to do it.**

Read a line from left to right. Find the verb first: jout prints, int stores a number, if compares, for repeats. Then find the value the verb works on. The example stores 3, prints it, and then repeats three times.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int count = 3;
    jout << count << "\n";
    for i in 0..count { jout << "repeat " << i << "\n"; }
}
```

```
3
repeat 0
repeat 1
repeat 2
```

> **Watch out:** The range 0..count stops before count. It runs 0, 1 and 2, not 3. This is the same rule as in 1..1001 in the machine lessons.
**Exercises**
- In the line int count = 3; which word is the name of the box that keeps the value?
  - a) int  b) count  c) 3  — Answer: b. count is the name of the box. The value 3 is kept in it, and int tells the type.
- Which verb checks if two values are equal?
  - a) print  b) compare  c) repeat  — Answer: b. Compare is the verb for questions like is this the same as that. The answer is yes or no.
- The line for i in 0..3 runs the body 3 times, for i = 0, 1 and 2. — Answer: t. The range 0..3 starts at 0 and stops before 3.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
for i in 0..2 { jout << "go " << i << "\n"; }
}
```
  Output: `go 0 / go 1`. The loop runs the body for i = 0 and for i = 1. It stops before 2.
- The verb that sends a value to the screen is ___. — Answer: **print**. In J2K the word jout is used with << to print a value.
- Store and print a number: write int n = 5 → write jout << n << "\n" → compile and run the file. A name must be made before you print it, so the store comes first.
**Tasks**
- **Count to two** — Write a program that repeats for i in 0..2 and prints the word tick and i on each turn. Output: `tick 0 / tick 1`. Hint: Use one for loop and jout with a space between the word and i.

## Nouns: name, value, type and list
**What it is.** A noun names a thing. In code, a name is the word you choose for a value, such as count or total. A value is the thing kept under the name, such as 3. A type says what kind of value it is, such as int for a whole number. A list is many values in one row, which the lessons call an array.
**Why it matters.** You write names, values, types and lists in every program. If you mix them up, the compiler gives you a message about the type, and you need the word to read it.
**How to do it.**

Read the declaration from left to right: the type comes first, then the name, then the value after the equal sign. The example has one name of type int with the value 4, and one list of three numbers.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int width = 4;
    int nums[3] = {10, 20, 30};
    jout << "width " << width << "\n";
    jout << "first " << nums[0] << "\n";
}
```

```
width 4
first 10
```

> **Watch out:** Counting starts at 0 in a list. The first value of nums is nums[0], not nums[1].
**Exercises**
- In int width = 4; which word is the type?
  - a) width  b) int  c) 4  — Answer: b. The type is the kind of value. int means a whole number, and the name is the word that comes after the type.
- In a list nums[3] which number is the first value?
  - a) nums[1]  b) nums[0]  c) nums[3]  — Answer: b. Lists start counting at 0, so the first value is nums[0].
- A name and a value are the same thing. — Answer: f. The name is the label of the box and the value is what is kept in it.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int nums[2] = {7, 8};
jout << nums[1] << "\n";
}
```
  Output: `8`. The index 1 is the second value in the list, and it is 8.
- A list of many values in one row is called an ___. — Answer: **array**. The array keeps values of the same type next to each other.
- Make a name and show its value: choose a name → give it a type → give it a value → print it. You must choose the name and the type before you can give a value.
**Tasks**
- **Two names** — Write a program with int a = 2 and int b = 5 and print the word sum and then a plus b. Output: `sum 7`. Hint: Use jout with the text sum, a space and a + b.

## Small words: if, else, while and for
**What it is.** Small words are the signs of control. if means only when the condition is true. else means in all other cases. while repeats as long as a condition is true. for repeats over a range of numbers. Each of them has a question in front of it that you can read in English.
**Why it matters.** Programs make choices and repeat work. If you read if and else as English, you can see the choice before you run the program.
**How to do it.**

Read the condition as a question. For example, if count is less than 3 means: is the count less than 3? If yes, the block runs. Otherwise the else block runs.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int count = 2;
    if count < 3 { jout << "small\n"; } else { jout << "big\n"; }
}
```

```
small
```

> **Watch out:** The condition must be a question with a yes or no answer. Write if count < 3 and not if count, because a number is not a yes or no.
**Exercises**
- In if x > 5 what does the word if mean?
  - a) always do this  b) only when the condition is true  c) do this forever  — Answer: b. if runs its block only when the condition is true. Otherwise it skips it.
- Which small word runs a block as long as a condition is true?
  - a) for  b) while  c) else  — Answer: b. while checks the condition before each turn and stops when it is false.
- else runs its block when the if condition is true. — Answer: f. else runs when the if condition is false, not when it is true.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int n = 1;
if n == 1 { jout << "one\n"; } else { jout << "other\n"; }
}
```
  Output: `one`. The condition n == 1 is true, so the first block runs.
- The word that repeats a block for each number in a range is ___. — Answer: **for**. for i in 0..3 runs the block for the numbers 0, 1 and 2.
- Read a choice in English: read the word if → read the condition as a question → read the block for yes → read the else block for no. The question comes first, then the two answers.
**Tasks**
- **Pick a word** — Write a program with int x = 9. If x is greater than 5, print big; otherwise print small. Output: `big`. Hint: Use if x > 5 with one block and else with the other block.

## Plural and singular
**What it is.** A singular word means one thing, and a plural word means many things. In code, a single value is a number, and a list is many values. The name of a list is often in the plural, such as numbers or names, because it holds many of them.
**Why it matters.** Good names say how many things they hold. If a list is called number instead of numbers, a reader thinks it holds one value, and the code becomes hard to read.
**How to do it.**

When you name a single value, use the singular, such as count or total. When you name a list, use the plural, such as scores or names. Then read the name in a sentence: the scores are ten and twenty.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int score = 10;
    int scores[2] = {10, 20};
    jout << "score " << score << "\n";
    jout << "scores " << scores[1] << "\n";
}
```

```
score 10
scores 20
```

> **Watch out:** Do not write a plural name for a single value. A name such as scores for one number is a lie that the next reader must fix.
**Exercises**
- Which name is best for one number that counts the students?
  - a) students  b) count  c) students_list  — Answer: b. count is singular and tells the reader that the value is one number.
- Which name is best for a list of the names of the students?
  - a) name  b) names  c) nameName  — Answer: b. names is plural and tells the reader that the list holds many values.
- The plural of list in an English name is a good name for a list that holds many values. — Answer: t. A plural name tells the reader that the variable holds more than one value.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int scores[2] = {3, 4};
jout << scores[0] + scores[1] << "\n";
}
```
  Output: `7`. The two values are added: 3 plus 4 is 7.
- A name for many values should be in the ___. — Answer: **plural**. Use the plural for lists, such as names or scores.
- Name a list of marks: choose a plural word, marks → write the type and the size → give the values → read one value by its index. A plural name is the first decision, so the reader knows the list holds many.
**Tasks**
- **Total score** — Write a program with int scores[3] = {1, 2, 3} and print the word total and the sum of the three values. Output: `total 6`. Hint: Use scores[0] + scores[1] + scores[2] in jout.

## Read a sentence as code
**What it is.** Many lines of code can be read as an English sentence. The sentence If the value is less than ten, print it means: check whether value is less than 10, and if the answer is yes, print value. Learning to turn a sentence into code is a skill of its own.
**Why it matters.** Most programs start as a sentence in your head. If you can write the sentence first and then turn it into code, the program is easier to get right.
**How to do it.**

Find the verb, the object and the condition in the sentence. Then write the condition after if, and the verb after it. The example turns the sentence If the value is less than ten, print it into code.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int value = 7;
    if value < 10 { jout << value << "\n"; }
}
```

```
7
```

> **Watch out:** A sentence with the word and often needs two conditions. Write each one as its own if, or join them with && in the same if.
**Exercises**
- Which code is the sentence If the value is zero, print the word none?
  - a) if value > 0 { jout << "none\n"; }  b) if value == 0 { jout << "none\n"; }  c) print none  — Answer: b. The condition value is zero is value == 0. The sign == means is equal to.
- What does the word it mean in print it?
  - a) the word print  b) the value that was checked  c) the program  — Answer: b. It refers to the value, the thing that was just named in the sentence.
- The equal sign = is used to ask a question about two values. — Answer: f. A single = gives a value to a name. To ask a question, use == instead.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int v = 4;
if v > 2 { jout << "more\n"; }
}
```
  Output: `more`. The sentence v is greater than 2 is true, so the block prints more.
- The sign for is equal to in a condition is ==, which is written as two ___. — Answer: **equal signs**. Two equal signs make a question. One equal sign gives a value.
- Turn a sentence into code: find the verb print → find the condition if value is less than ten → write if value < 10 → write the block with jout. The verb and the condition are found before you write the code.
**Tasks**
- **Sentence code** — Write a program with int age = 12. If age is less than 18, print minor. Output: `minor`. Hint: Use if age < 18 with jout inside the block.

## Comments in English
**What it is.** A comment is a note for the reader. The compiler skips it. Two slashes // make a comment to the end of the line. Slash and star /* ... */ make a comment that can cover many lines.
**Why it matters.** The code says what happens. A comment says why. Write comments in plain English, so that the next learner can read them.
**How to do it.**

Write a short comment above a hard line, and say why it is there, not what the code already says. The example has one comment that explains the purpose of the number.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    // 60 seconds make one minute
    int seconds = 60;
    jout << seconds << "\n";
}
```

```
60
```

> **Watch out:** A comment that repeats the code, such as add one to x above x = x + 1, adds no help. Explain the reason instead.
**Exercises**
- Which line is a good comment?
  - a) // x = x + 1  b) // add the tax, because the price is before tax  c) // int x  — Answer: b. A good comment explains why. The first choice only repeats the code.
- How do you write a comment that covers three lines?
  - a) with // on each line only  b) with /* and */ around the lines  c) with a hash  — Answer: b. /* starts the comment and */ ends it, so one comment can cover many lines.
- The compiler reads the text in a comment and runs it. — Answer: f. The compiler skips a comment. It is only for the reader.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
// this line is not printed
jout << "shown\n";
}
```
  Output: `shown`. The line that starts with // is a comment and is skipped.
- The two characters that start a comment to the end of a line are ___. — Answer: **//**. Two slashes make a comment to the end of the line.
- Write a useful comment: read the line that needs a note → decide why it is there → write the reason in plain English → put the comment above the line. The reason is the part that the code does not say.
**Tasks**
- **Commented print** — Write a program that has one comment with the word hello and prints the word done. Output: `done`. Hint: Use // for the comment and jout for done.

## Good names
**What it is.** A name should say what the value is for. count, total and first_name are good names. x, tmp and data are short names that do not tell the reader anything. A name in English is easier to read when it uses simple words, and the underscore _ joins two words.
**Why it matters.** You read a name many more times than you write it. A good name saves the reader from looking back to the place where the value was made.
**How to do it.**

Choose a name that answers the question what is this for? Use a short English word or two, with an underscore between the words. Do not use a name that is only a letter, except for a loop index such as i.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int first_score = 8;
    int total_score = first_score + 2;
    jout << "total " << total_score << "\n";
}
```

```
total 10
```

> **Watch out:** A name can be too clever. tmp2 says nothing. Use a name that a learner can read aloud.
**Exercises**
- Which name says the most about the value?
  - a) x  b) total_score  c) t2  — Answer: b. total_score tells the reader what the value means. x and t2 do not.
- Which name is normal for a loop index?
  - a) i  b) total  c) last_value_of_the_loop  — Answer: a. i is the normal name for a loop index. It is the only time a one-letter name is good.
- The underscore in first_name is a space that is not allowed. — Answer: t. A name cannot have a space, so the underscore joins the two words.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int count = 3;
int total_count = count + 1;
jout << total_count << "\n";
}
```
  Output: `4`. count is 3, and one is added, so total_count is 4.
- A name for the sum of scores could be total___. — Answer: **score**. total_score says what the value is for: the total of the scores.
- Pick a good name for a value: say what the value is for → write it in simple English words → join the words with an underscore → check that a reader understands it. The meaning comes first. The name follows from it.
**Tasks**
- **Good name** — Write a program with int apple_count = 4 and print the word apples and the value of apple_count. Output: `apples 4`. Hint: Use jout with the text apples, a space and apple_count.

## Adjectives: big, small, empty
**What it is.** An adjective describes a noun. In code the value of a name can be big, small or empty. A big number is greater than another number, a small one is less. An empty list has no values in it, and a count of zero means there is nothing to count.
**Why it matters.** Many lessons say "if the list is empty" or "if the value is bigger". If you know the adjectives, you can read the condition at once and know what the program checks.
**How to do it.**

Turn the adjective into a comparison. Big means greater than, small means less than, and empty means the count is zero. The example checks a count that is zero and prints a message for the empty case.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int count = 0;
    if count == 0 { jout << "empty\n"; } else { jout << "not empty\n"; }
}
```

```
empty
```

> **Watch out:** The word empty is not a special keyword. It is a plain check such as count == 0, so write the check you mean.
**Exercises**
- If a list is empty, what is its count?
  - a) 1  b) 0  c) empty  — Answer: b. Empty means there are no values, so the count is zero.
- Which condition means the value is small?
  - a) value > 100  b) value < 10  c) value == 10  — Answer: b. Small means the value is less than some limit, here 10.
- The adjective big means greater than in a comparison. — Answer: t. Big is the word for a larger number, so it becomes the sign greater than.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int n = 5;
if n > 3 { jout << "big\n"; }
}
```
  Output: `big`. The value 5 is greater than 3, so the adjective big is true.
- A count of zero means the list is ___. — Answer: **empty**. Zero values means the list has nothing in it.
- Check an empty list: write the count → compare it with zero → print the message for empty → print the other message. The count must exist before it is compared.
**Tasks**
- **Big check** — Write a program with int n = 50. If n is big, meaning greater than 10, print big. Otherwise print small. Output: `big`. Hint: Use if n > 10 with jout in the block.

## Numbers in words: zero, first, last, half
**What it is.** Some number words have a special meaning in programming. Zero is the count of nothing. The first value of a list has index 0, not 1. The last value has the index one less than the size. Half of a number is that number divided by two.
**Why it matters.** Off-by-one bugs come from mixing up the words first, last and zero. When you read the word first, think of index 0 in code.
**How to do it.**

For a list of size 4 the first index is 0 and the last index is 3. The example prints both, and half of 10 is 5.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int nums[4] = {5, 6, 7, 8};
    jout << "first " << nums[0] << "\n";
    jout << "last " << nums[3] << "\n";
}
```

```
first 5
last 8
```

> **Watch out:** The last index of a list of size 4 is 3, not 4. An index of 4 is past the end of the list.
**Exercises**
- In a list of size 4, which index is the last value?
  - a) 4  b) 3  c) 0  — Answer: b. Indexes start at 0, so for four values the last index is 3.
- What is the first index of any list?
  - a) 1  b) 0  c) the size  — Answer: b. The first value always has index 0 in J2K.
- Half of 9 as a whole number is 4. — Answer: t. Integer division of 9 by 2 keeps only the whole part, which is 4.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int a[3] = {2, 4, 6};
jout << a[0] << "\n";
}
```
  Output: `2`. The first value of the list has index 0, and it is 2.
- The index of the first value in a list is ___. — Answer: **0**. Lists count from zero, so the first value is at index 0.
- Read the last value of a list: write the list → find its size → subtract one for the last index → read the value at that index. The last index is one less than the size, so subtract first.
**Tasks**
- **Last value** — Write a program with int a[3] = {7, 8, 9} and print the word last and then the last value. Output: `last 9`. Hint: The last index of three values is 2.

## Question words: what, which, why, how
**What it is.** A question word starts a question. What asks for the thing. Which asks you to choose from a set. Why asks for the reason. How asks for the steps or the method. Exercises and error messages use these words, so you must understand them to answer.
**Why it matters.** In a quiz or a lesson the question tells you the kind of answer that is wanted. A question that asks why needs a reason, not a name.
**How to do it.**

Find the question word first. Then decide what the answer must contain: a name, a choice, a reason or steps. The example answers a what question by printing the value.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int width = 6;
    jout << "What is the width? " << width << "\n";
}
```

```
What is the width? 6
```

> **Watch out:** Why and how questions need a sentence. A single word such as because is not enough, and a value is not a method.
**Exercises**
- Which question word asks you to choose from a set of answers?
  - a) what  b) which  c) why  — Answer: b. Which means choose one from the set given.
- Which question word asks for the reason?
  - a) how  b) what  c) why  — Answer: c. Why asks for the reason something happens.
- A how question asks for the steps of a method. — Answer: t. How asks you to describe the way something is done.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int x = 2;
jout << "x is " << x << "\n";
}
```
  Output: `x is 2`. The program prints the text and then the value of x.
- The question word that asks for the reason is ___. — Answer: **why**. Why asks you for a reason, such as why a loop stops.
- Answer a how question: read the question → find the steps → write them in order → check the answer has steps not one word. A how answer lists the steps, so it cannot be one word.
**Tasks**
- **Which value** — Write a program with int a = 3 and int b = 8 and print the word larger and the larger of the two values. Output: `larger 8`. Hint: Use an if with a > b and else with b.

## Opposites: before and after, true and false
**What it is.** Opposite words mark two sides of a rule. Before and after show the order of steps. True and false are the two values of a condition. Greater and less show the two sides of a comparison. Reading the opposite is as important as reading the word itself.
**Why it matters.** A bug often comes from reading the opposite. If you think after when the code runs before, the value you read is the old one.
**How to do it.**

For each condition, ask: which side is the true one? For each order, ask: which step runs first? The example prints the old value before the change and the new value after it.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int x = 1;
    jout << "before " << x << "\n";
    x = x + 5;
    jout << "after " << x << "\n";
}
```

```
before 1
after 6
```

> **Watch out:** A value printed before a change is not the value after it. Print at the place you want to know about.
**Exercises**
- In the code, the print that comes before the change shows the value:
  - a) the new value  b) the old value  c) a random value  — Answer: b. Before the change the value is still the old one.
- The opposite of true in a condition is:
  - a) false  b) after  c) zero  — Answer: a. False is the other value of a condition.
- If the code prints after x = x + 5, the printed value is the old one. — Answer: f. After the change the value is the new one.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int n = 2;
n = n * 3;
jout << n << "\n";
}
```
  Output: `6`. The change happens before the print, so the new value 6 is printed.
- The opposite of greater is ___. — Answer: **less**. Greater and less are the two sides of a comparison.
- Trace a change in order: write the start value → print it as before → apply the change → print it as after. The order of the steps shows which value each print sees.
**Tasks**
- **Before and after** — Write a program with int y = 4, print before and y, then add 2 to y, then print after and y. Output: `before 4 / after 6`. Hint: Print the first value, change y with y += 2, then print again.

## One word, two meanings
**What it is.** Many words have two meanings in programming. Return can mean to send a value back from a function, or to go back to the place it was called from. Count can be a noun, the number, or a verb, to count the items. Value can mean the thing kept under a name, or the number in a field. Read the sentence to find the meaning.
**Why it matters.** If you read count as a verb when it is a noun, you will misread the code. The word around the name tells you which meaning is meant.
**How to do it.**

Look at the words around the word. In return 0; the word return sends back a value. In count = count + 1 the name is a number. The example uses the two words count and return in one function.
**Example.**

```jk
#import <stdlib>
using stdlib;

int twice(int v) {
    return v * 2;
}

void main() {
    int count = twice(4);
    jout << "count " << count << "\n";
}
```

```
count 8
```

> **Watch out:** Return ends the function at that line. Lines written after a return in the same block are not run.
**Exercises**
- In return v * 2; what does return do?
  - a) It stops the program forever  b) It sends a value back from the function  c) It prints the value  — Answer: b. Return gives the value back to the caller and leaves the function.
- In count = count + 1, what is count?
  - a) a verb  b) a name for a number  c) a sentence  — Answer: b. Here count is the name of a number that is changed.
- The word value always means the printed text. — Answer: f. A value is the thing kept under a name, and it can be a number, a text or a struct.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

int twice(int v) {
return v * 2;
}

void main() {
jout << twice(3) << "\n";
}
```
  Output: `6`. Return sends 3 times 2, which is 6, back to the caller.
- The word that sends a value back from a function is ___. — Answer: **return**. return ends the function and gives back the value.
- Read a function call: find the name of the function → find the value sent in → find the return that gives back the result → use the result. The call sends the value in, and return sends the result out.
**Tasks**
- **Return twice** — Write a function int triple(int v) that returns v times 3, and print the result for 4 with the word triple before it. Output: `triple 12`. Hint: Use return v * 3; and call triple(4) inside jout.

## Subject, verb and object
**What it is.** An English sentence has a subject, a verb and an object. In a line of code, the subject is often the name of the value, the verb is the action, and the object is what the action is done to. Print the count has the verb print and the object count.
**Why it matters.** Long lines are hard to read. If you split the line into subject, verb and object, you can see what changes and what is only read.
**How to do it.**

Find the verb first. Then ask: what does the verb act on? The object is the answer. In total = total + n the verb is a change and the object is total.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int total = 0;
    int n = 5;
    total = total + n;
    jout << total << "\n";
}
```

```
5
```

> **Watch out:** A line with two names can change only one of them. Find the name on the left of the equal sign, that is the object that changes.
**Exercises**
- In total = total + n, which name changes?
  - a) n  b) total  c) both  — Answer: b. Only the name on the left of the equal sign is changed; n is only read.
- In print the count, what is the object?
  - a) print  b) the  c) count  — Answer: c. The object is what the verb acts on, the count.
- In the line x = y, the value of y is changed. — Answer: f. The name on the left, x, is the one that is changed.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int a = 2;
int b = 3;
a = a + b;
jout << a << "\n";
}
```
  Output: `5`. The object a changes to 2 plus 3, which is 5.
- In a line of code the name that changes is on the ___ of the equal sign. — Answer: **left**. The name on the left of = is the one that receives the new value.
- Read a line of code as a sentence: find the verb → find the object that the verb acts on → find the subject that does it → say the sentence in English. The verb comes first, then the object, then the subject.
**Tasks**
- **Add a name** — Write a program with int a = 4 and int b = 6, change a to a plus b, and print the value of a. Output: `10`. Hint: Use a = a + b; and then jout.

## Error words: expected, unknown, missing, cannot
**What it is.** Compiler messages use a few words again and again. Expected means the compiler wanted something else at this place. Unknown means the name is not defined. Missing means a part is not written, such as a semicolon or a brace. Cannot means the thing is not allowed. Learn these four words and most messages become clear.
**Why it matters.** Each word points to a different kind of fix. Unknown needs a definition or an import. Missing needs a character added. Cannot needs a different type or cast.
**How to do it.**

Read the word first, then go to the place the message names. For unknown, check the spelling and the import. For missing, look at the end of the line before. For cannot, read the types on each side. The example has no error but names a value that is defined.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int value = 9;
    jout << value << "\n";
}
```

```
9
```

> **Watch out:** Missing often points one line too late. The real missing character is usually at the end of the line before the message line.
**Exercises**
- A message says unknown name. What is the usual fix?
  - a) Add a semicolon  b) Check the spelling and the import  c) Change the type to double  — Answer: b. Unknown means the name is not known, so check the spelling and the import that defines it.
- A message says missing semicolon. Where do you look first?
  - a) at the end of the line before  b) at the last line of the file  c) nowhere  — Answer: a. The missing character is usually at the end of the line before the message.
- Cannot in a compiler message means the operation is allowed but slow. — Answer: f. Cannot means the thing is not allowed, so you change the code.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int value = 9;
jout << value << "\n";
}
```
  Output: `9`. The name value is defined, so there is no unknown name, and the value 9 is printed.
- The compiler word that means a name is not defined is ___. — Answer: **unknown**. Unknown means the name has not been declared or imported.
- Fix a missing part: read the message → go to the line before it → add the missing character → compile again. Compile again after each fix to see the next message.
**Tasks**
- **Defined name** — Write a program with int item = 2 and print the word item and its value. Output: `item 2`. Hint: Use jout with the word, a space and item.

## Reading headings and the index
**What it is.** A document has headings, the lines that start with # or ##, and an index of words. A heading tells you the topic of the lines under it. The index tells you on which page a word is found. Reading the heading first saves time, because you know if the topic is the one you need.
**Why it matters.** The lessons and the language guide are long. A learner who reads headings first finds the answer in minutes instead of reading all the text.
**How to do it.**

Read the title, then the headings in order. Pick the heading that matches your question, read it, and only then the lines under it. Search for one word with the search tool when you know the name.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    // heading: printing
    jout << "printing is the first topic\n";
}
```

```
printing is the first topic
```

> **Watch out:** A heading that is too general, such as Notes, may hide the answer. Read the lines under it before you decide the topic is wrong.
**Exercises**
- What does a heading tell you?
  - a) The price of the book  b) The topic of the lines under it  c) The name of the author  — Answer: b. A heading names the topic of the section below it.
- When you know a word, what is the fastest way to find it in a long document?
  - a) read every line  b) search for the word  c) guess a page  — Answer: b. A search for the word goes straight to the lines that use it.
- A heading tells you nothing about the lines under it. — Answer: f. The heading is the topic of those lines, so it guides your reading.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
// heading: loops
jout << "loops\n";
}
```
  Output: `loops`. The comment is skipped. The program prints the text in jout.
- A line in a document that starts with # is a ___. — Answer: **heading**. A # line is a heading, and the number of # tells the level.
- Find an answer in a long lesson: read the title → read the headings → choose the heading that matches → read its lines. The headings are read before the text, to save time.
**Tasks**
- **Heading print** — Write a program that prints the word heading and then the word index. Output: `heading index`. Hint: Use jout with the two words and a space, and end with \n.
