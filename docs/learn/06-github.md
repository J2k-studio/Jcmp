# 6. Putting your project on GitHub

GitHub keeps your project, with its whole history, and lets others read it. `git` is the program on your computer; GitHub is the place on the internet.

## Once: install and introduce yourself
```
pkg install git gh                     # Termux; on other systems install git and the GitHub CLI
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```
## Once: make the project a repository
```
cd Jdesk
git init                               # starts the history in this folder
printf '_out/\n' > .gitignore          # things that are built are not kept
git add .                              # choose what goes into the next save
git commit -m "first version: home and about pages"
```
A **commit** is a save point with a message. Write what changed and why, in one line.

## Once: make the place on GitHub and send the project
1. In the browser: github.com, **New repository**, name `Jdesk`, choose Private or Public, do not add a README (you have one).
2. Log in from the terminal: `gh auth login` (follow the questions; it opens a browser or gives a code).
3. Connect and send:
```
git branch -M main
git remote add origin https://github.com/YOURNAME/Jdesk.git
git push -u origin main
```
## Every day
```
git status                  # what changed
git add -A                  # take all changes (check the list first)
git commit -m "notes page: save a note to data/"
git push                    # send
git pull                    # bring what is on GitHub (from another phone, or a friend)
git log --oneline           # the history
```
## Good habits
- Commit small and often: one idea, one commit. Run your tests before you push.
- **Never put a password, a token or a key in the repository.** If it was pushed, change the password at once: deleting the file does not remove it from the history.
- A branch is a copy to try something: `git switch -c new-page`, work, `git switch main`, `git merge new-page`.
- A **release** is a tagged version with files: `git tag v0.1.0 && git push origin v0.1.0`, then `gh release create v0.1.0 _out/Jdesk.apk`.
- A `README.md` says what the project is, how to build it, and where things are. A `LICENSE` says what others may do with it.

## Questions
1. What is the difference between `git add`, `git commit` and `git push`?
2. You pushed a file with a token inside. What are the two things to do?
3. Make a branch, change one page, merge it, and look at `git log --oneline`.
