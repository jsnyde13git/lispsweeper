#! /usr/local/bin/sbcl --script
; A Lisp program to run a version of Minesweeper in a terminal.


; Initialize the random state.
(setf *random-state* (make-random-state t))

(defun two-int-listp (x)
    "Checks if an item is a list with exactly two integers."
    (if (listp x) 
        (if (listp (rest x))
            (and (integerp (car x)) 
                 (integerp (cadr x)) 
                 (EQL (list-length x) 2)) 
            NIL)
    NIL))


(defun read-int-pair 
    (&key (prompt "Please enter a pair of integers (a b).") 
          (reprompt "Invalid form. Please enter the integers as (a b) (include parentheses, space-separated)."))
    "Reads a pair of integers."
    (format t "~a~%" prompt)
    (let ((input (ignore-errors (read))))
        (if (two-int-listp input) 
            input
            (do () ((two-int-listp input) input)
                (format t "~a~%" reprompt)
                (setf input (ignore-errors (read)))))))

(defun read-ratio (&key (min 0) 
                        (max 1) 
                        (prompt "Please enter a ratio between 0 and 1.") 
                        (reprompt "Invalid form. Please enter a ratio between 0 and 1 (no parentheses)"))
    "Reads a ratio between min and max (inclusive).
    If unspecified, min = 0, max = 1, and prompts are set accordingly.
    If min *or* max is changed, prompt and reprompt *must* be changed as well."
    (format t "~a~%" prompt)
    (let ((input (ignore-errors (read))))
        (if (and (rationalp input) (>= input min) (<= input max))
            input
            (do () ((and (rationalp input) (>= input min) (<= input max)) input)
                (format t "~a~%" reprompt)
                (setf input (ignore-errors (read)))))))

(defun print-board (board)
    "Prints a 2d matrix, where elements are separated by spaces.
    Works best where every element is a single character."
    (format t "   ")
    (reduce (lambda (n x) 
                    (format t "~a " n)
                    (+ n 1))
            (car board)
            :initial-value 0)
    (format t "~%~%")
    (reduce (lambda (n lst)
                    (format t "~a  " n) 
                    (mapcar (lambda (x) (format t "~a " x)) lst)
                    (format t "~%")
                    (+ n 1))
            board
            :initial-value 0)
)
    

(defun valid-wordp (symbol)
    "Determines whether a cmd word is valid.
    Valid words are reveal, flag, and ?."
    (or (EQUAL symbol 'reveal) (EQUAL symbol 'flag) (EQUAL symbol '?)))

(defun valid-cmdp (input board-width board-height)
    "Determines whether a command is valid.
    Commands are three-input lists, with the form (cmd x y)
    If the cmd is reveal, flag, or ?,
    and its coordinates are within the board,
    returns true. Else returns false."
    (and 
        (listp input) 
        (EQL (list-length input) 3) 
        (valid-wordp (car input))
        (let ((x (cadr input)) (y (caddr input)))
            (and 
                (>= x 0)
                (< x board-width)
                (>= y 0)
                (< y board-height)))))

(defun get-input (validp prompt reprompt)
    "Generic input-reading function.
    Prints prompt.
    Then, checks if input matches the valid condition passed.
    If yes, returns it.
    If no, prints reprompt and restarts from step 2.
    Will return input that matches validp."
    (format t "~a~%" prompt)
    (let ((input (ignore-errors (read))))
        (if (funcall validp input)
            input
            (do () ((funcall validp input) input)
                (format t "~a~%" reprompt)
                (setf input (ignore-errors (read)))))))


(defun set-matrix-elem (matrix x y elem)
    "Set an element of a matrix. Does not do bounds checking."
    (setf (elt (elt matrix y) x) elem)) 

(defun get-matrix-elem (matrix x y)
    "Get an element of a matrix. Does not do bounds checking."
    (elt (elt matrix y) x))

(defun truth-to-bit (bool) 
    "Converts a boolean to 1 if true, and 0 if false."
    (if bool 1 0))

(defun get-mine-number (mines x y)
    "Get the number of mines around a square.
    It does count the square itself if it is a mine;
    include a separate check for whether it's a mine."
    (let ((num 0))
        ; Iterate over each combination of -1, 0, and 1 for x and y.
        ; Gets all items within a 3x3 square centered on the tile chosen.
        (dolist (xoff '(-1 0 1))
            (dolist (yoff '(-1 0 1))
                (let ((xi (+ x xoff)) (yi (+ y yoff)))
                    (if (and  (valid-2d-indexp mines xi yi)
                              (get-matrix-elem mines xi yi))
                        (incf num)))))
        num))
    
(defun valid-2d-indexp (matrix x y)
    "Check if a 2d index is within the bounds of a 2d matrix.
    Rather inefficient (it'd be much better to cache the matrix size and check with that),
    but it works for this application, since triple-digit board sizes hardly even fit in the CLI anyway."
    (and (>= y 0) 
         (< y (length matrix)) 
         (>= x 0) 
         (< x (length (elt matrix y)))))

(defun reveal-1-square (mine-matrix revealed-matrix x y)
    "Reveals just 1 square."
    (let ((mine-ct (get-mine-number mine-matrix x y)))
        (if (EQL mine-ct 0)
            ; 0 mines; replace with solid block
            (setf (elt (elt revealed-matrix y) x) #\█)
            ; Some mines; replace with number of mines
            (setf (elt (elt revealed-matrix y) x) mine-ct))))

(defun reveal-squares (mine-matrix revealed-matrix x y)
    "Reveals a square, cascading if it has 0 mines around it.
    The cascade reveals *all 8* neighbors of the square; 
    this can create some weird-looking cascades if there are two 0-mine squares connected by a diagonal,
    but that's minor enough that it's not worth dealing with."
    ; We have a queue of squares to check.
    ; Process elements until the queue is empty.
    ; If a square is 0 mines & unrevealed, we first reveal it, 
    ; then we add its _unrevealed_ neighbors to the queue.
    ; If a square is nonzero mines & unrevealed, we reveal it but do not queue its neighbors.
    (let ((queue (list (list x y))))
        (do () ((null queue) nil)
            ; We use this let to destructure the first element of the queue,
            ; and get the number of mines and whether it's hidden.
            (let* ((cx (caar queue))
                  (cy (cadar queue))
                  (num-mines (get-mine-number mine-matrix cx cy))
                  (hidden (eql #\░ (get-matrix-elem revealed-matrix cx cy))))

                ; Remove the first element from the queue.
                (setf queue (cdr queue))

                ; If the square is hidden, reveal it, then if it has 0 mines,
                ; reveal all its neighbors (by adding them to the queue).
                (if hidden
                    (progn (reveal-1-square mine-matrix revealed-matrix cx cy)
                        (if (eql num-mines 0)
                            ; 0 mines & hidden
                            ; Add unrevealed neighbors to queue
                            (let ((reslist nil))
                                ; Iterate over neighbor coordinates, and add any valid indexes to a list.
                                ; Then, append the list to the queue.
                                ; Normally we'd reverse the list, but order doesn't matter here, 
                                ; since it's all added to the end of the queue regardless.
                                (dolist (pos (list '(-1 -1) '(-1 0) '(-1 1) '(0 -1) '(0 1) '(1 -1) '(1 0) '(1 1)))
                                    (let ((nx (+ cx (car pos))) (ny (+ cy (cadr pos))))
                                        (when (valid-2d-indexp mine-matrix nx ny) 
                                              (push (list nx ny) reslist))))
                                (setf queue (nconc queue reslist))))))))))

(defun true-ct (lst)
    "Returms the number of true values in a list."
    (reduce (lambda (x y) (+ x (truth-to-bit y))) lst :initial-value 0))

(defun true-ct-mat (matrix)
    "Returns the number of true values in a matrix (2d list)."
    (reduce (lambda (x y) (+ x (true-ct y))) matrix :initial-value 0))
    

; Game is actually run here.
(let (board-x board-y mine-ct (flag-ct 0)) 
    ; Read in the dimensions and record the values.
    (let ((dimensions (read-int-pair :prompt "Please enter two numbers (x y) for the board dimensions:")))
        (setf board-x (car dimensions))
        (setf board-y (cadr dimensions)))

    ; Generate the matrices & run the game.
    (let (mine-matrix revealed-matrix mine-ratio)
        ; Initialize the matrices.
        (setf mine-matrix (mapcar (lambda (_) (make-list board-x)) (make-list board-y)))
        (setf revealed-matrix (mapcar (lambda (_) (make-list board-x :initial-element #\░)) (make-list board-y))) ;(make-list board-y :initial-element (make-list board-x :initial-element #\░)))
        
        ; Read in the ratio of mines from the user.
        (setf mine-ratio (read-ratio :prompt (format nil 
                                                "Please enter the proportion of mines (ratio between 0 and 1). Examples:~%Beginner: 12/100~%Intermediate: 15/100~%Expert: 20/100")))
        
        ; Generate the board with the given ratio, then count & record the number of mines.
        (setf mine-matrix (mapcar (lambda (lst) (mapcar (lambda (_) (if (< mine-ratio (random 1.0)) nil t)) lst)) mine-matrix))
        (setf mine-ct (true-ct-mat mine-matrix))

        ; Main game loop. 
        (do ((end nil)) (end nil)
            ; Print the board status (board & num mines left)
            (print-board revealed-matrix)
            (format t "~a mines left~%" (- mine-ct flag-ct))
            ; Wait for player input.
            (let ((input (get-input 
                                    (lambda (cmd) (valid-cmdp cmd board-x board-y))
                                    "Please enter a command and position. Commands are reveal, flag, and ?. Example: (reveal 0 0)" 
                                    "Invalid command. Valid commands are reveal, flag, and ?. Example: (reveal 0 0)")))
                
                ; Process command
                (let ((cmd (car input)) 
                      (x (cadr input)) 
                      (y (caddr input)))
                    ; Switch on command name.
                    (cond 

                        ; Reveal command.
                        ((eql (first input) 'reveal)
                            ; Revealed square.
                            ; First, check if mine. If mine, explode & end game.
                            ; Otherwise, reveal the square.
                            (if (get-matrix-elem mine-matrix x y)
                                (progn 
                                    (format t "Mine hit! 💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥~%")
                                    (setf end t))
                                (progn 
                                    ; Successfully revealed.
                                    ; First, we set the appropriate position with the appropriate character.
                                    ; If there are 0 mines, we use solid block █ and reveal its neighbors.
                                    ; If there are a number of mines, we use that number.
                                    (reveal-squares mine-matrix revealed-matrix x y))))

                        ; Question mark command.
                        ((eql cmd '?)
                            (cond 
                                ((eql (get-matrix-elem revealed-matrix x y) #\░)
                                    (set-matrix-elem revealed-matrix x y #\?))
                                ((eql (get-matrix-elem revealed-matrix x y) #\?)
                                    (set-matrix-elem revealed-matrix x y #\░))
                                (t (format t "Cannot ? square that isn't hidden.~%"))))

                        ; Flag command.
                        ((eql cmd 'flag)
                            (cond
                                ; If the square is a flag, remove it and decrement the flag count..
                                ((eql (get-matrix-elem revealed-matrix x y) #\!)
                                    (set-matrix-elem revealed-matrix x y #\░)
                                    (decf flag-ct))

                                ; If the square is either a ? or hidden, flag it, and increment the flag count.
                                ((or (eql (get-matrix-elem revealed-matrix x y) #\?)
                                     (eql (get-matrix-elem revealed-matrix x y) #\░))
                                    (set-matrix-elem revealed-matrix x y #\!)
                                    (incf flag-ct))

                                ; Otherwise, print an error.
                                (t (format t "Cannot flag square that isn't hidden.~%")))))))
                        
                    ; Check if board is cleared. 
                    ; Specifically, we check that the number of flags equals the number of mines,
                    ; and there are no spaces hidden or ?s (all revealed)
                    (if (and (eql mine-ct flag-ct) 
                             (every (lambda (ls) 
                                        (every (lambda (x) 
                                            (and (not (eql x #\░)) 
                                                 (not (eql x #\?)))) 
                                            ls)) 
                            revealed-matrix))
                        ; Board is cleared.
                        ; So we set the game to end and print a victory message.
                        (progn 
                            (setf end t)
                            (format t "Victory!~%"))))))