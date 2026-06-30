# Lispsweeper

A CLI Minesweeper implementation in Common Lisp. 

## Install & Run
Lispsweeper is only guaranteed to work on Linux with SBCL.  
Install SBCL, download the script, and mark it as executable with chmod u+x lispsweeper. Then, run with ./lispsweeper.  
Minor modification may be needed to run on non-Linux systems or with other Common Lisp implementations; most likely, remove the #! line at the beginning of the file, then use your Common Lisp implementation's preferred way to run Lisp source files.

## Gameplay

To set up a beginner game, input the size as (9 9) and mine ratio as 12/100. Intermediate is size (16 16) and ratio 15/100; expert is size (30 16) and ratio 20/100. 

To play, type (reveal x y) to reveal a square, (flag x y) to flag a square, and (? x y) to question-mark a square. The game ends when either a mine is revealed, or when all non-mine squares are revealed and all mine squares are flagged.

## Notes

Mine count is not static for a given ratio; each square has an independent random chance to be a mine. Thus, mine count will vary each time a game is started.

No guarantee is made that the first reveal is safe or useful.  
