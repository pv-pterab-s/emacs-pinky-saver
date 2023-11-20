;;; -*- lexical-binding: t; -*-

;;;;;;;;;;;;;;;;;;;;;; emacs ui
(defun gdp-open-voice-control-window ()
  (interactive)
  (let* ((frame-height (frame-height))
         (new-window-height (max 1 (floor (* 0.2 frame-height)))))
    ;; Check if "*Voice Control*" buffer is already visible
    (unless (get-buffer-window "*Voice Control*" 'visible)
      ;; Split the selected window and create the Voice Control window at the bottom
      (let ((new-window (split-window (selected-window) (- new-window-height) 'below)))
        (with-current-buffer (get-buffer-create "*Voice Control*")
          (unless (eq major-mode 'compilation-mode)
            (compilation-mode))  ;; Set "*Voice Control*" buffer to use compilation mode
          (setq-local window-min-height new-window-height)
          (setq buffer-read-only nil)  ;; Compilation-mode needs to insert text
          (setq mode-line-format "Voice Control")  ;; Set a custom mode-line format
          (set-window-buffer new-window (current-buffer)))
        ;; Make the window dedicated and avoid selecting it in `other-window` commands
        (set-window-dedicated-p new-window t)
        (set-window-parameter new-window 'no-other-window t)))
    (message "Voice Control window opened.")))

(defun gdp-close-voice-control-window ()
  (interactive)
  ;; Check if the Voice Control buffer exists.
  (let ((voice-control-buffer (get-buffer "*Voice Control*")))
    (when voice-control-buffer
      ;; Check if the Voice Control window exists.
      (let ((voice-control-window (get-buffer-window voice-control-buffer 'visible)))
        (when voice-control-window
          ;; Delete the window.
          (delete-window voice-control-window)))
      ;; Kill the buffer.
      (kill-buffer voice-control-buffer)
      (message "Voice Control window closed and buffer killed."))))

(defun gdp-voice-control-message (text)
  (with-current-buffer (get-buffer-create "*Voice Control*")
    (let ((inhibit-read-only t))  ; Temporarily allow modifications in read-only buffer
      ;; Move point to the end of the buffer to append text
      (goto-char (point-max))
      ;; Insert the text and a newline
      (insert text "\n"))
    ;; If the buffer is displayed in a window, make sure it is scrolled to the bottom
    (let ((vc-window (get-buffer-window (current-buffer) 'visible)))
      (when vc-window
        (with-selected-window vc-window
          (goto-char (point-max))
          (recenter -1))))))  ; '-1' recenters with the last line at the bottom of the window



;; A helper function that updates the Voice Control window height
(defun gdp-update-voice-control-window-height ()
  (with-current-buffer "*Voice Control*"
    (let* ((voice-control-window (get-buffer-window (current-buffer) 'visible))
           (frame-height (frame-height))
           (new-window-height (max 1 (floor (* 0.07 frame-height)))))
      ;; Update the window height
      (when voice-control-window
        (window-resize voice-control-window (- new-window-height (window-height voice-control-window)) t)))))

(defun gdp-voice-control-log (text)
  "Write a log message TEXT to the *Voice Control* buffer."
  (gdp-voice-control-message (format "[%s] %s" (format-time-string "%H:%M:%S") text)))



;;;;;;;;;;;;;;;; ai interface
(defun gdp-send-single-prompt-to-chatgpt (prompt callback &optional preserve-conversation)
  "Send a single PROMPT to ChatGPT and call CALLBACK with the response.
If PRESERVE-CONVERSATION is non-nil, do not erase the existing conversation."
  (let* ((buffer-name "GDP ChatGPT Session")
         response-start) ; Marker for where the response starts

    ;; Prepare the buffer, only kill the buffer if preserve-conversation is nil
    (unless preserve-conversation
      (when (get-buffer buffer-name)
        (kill-buffer buffer-name)))

    (with-current-buffer (get-buffer-create buffer-name)
      (when preserve-conversation
        (goto-char (point-max))
        (insert "\n\n"))

      ;; Define a local post-response action
      (defun gdp-local-post-response-action ()
        (with-current-buffer buffer-name
          (let ((response (buffer-substring (point-marker) (point-max))))
            (remove-hook 'gptel-post-response-hook 'gdp-local-post-response-action t)
            (funcall callback response)
            )))

      ;; Set up the hook to call the local post-response action
      (add-hook 'gptel-post-response-hook 'gdp-local-post-response-action nil t)

      ;; Send the prompt to ChatGPT and mark the start of the response
      (insert prompt)
      (gptel-send)))
  )





(require 'cl-lib)
(require 'subr-x)

(defun gdp-multi-replace (input-str pattern-replacements)
  "Replace multiple patterns in INPUT-STR based on PATTERN-REPLACEMENTS.

PATTERN-REPLACEMENTS is a list of cons cells, each containing a pattern string
and its corresponding replacement string."
  (let ((result input-str)
        (case-replace nil))
    (dolist (pair pattern-replacements result)
      (let ((pattern (car pair))
            (replacement (cdr pair)))
        (setq result (replace-regexp-in-string pattern replacement result t))))))

(defun gdp-tts-synthesize-and-play-async (text)
  (let ((script-path (concat (getenv "HOME") "/voice-interface/text_to_speech.sh"))  ; Adjust this to the actual path
        (output-buffer (get-buffer-create "*tts-synthesis-output*")))
    (with-current-buffer output-buffer
      (erase-buffer))  ; Clear the buffer before running the script.
    (gdp-voice-control-log (format "saying: %s" text))
    (let ((process (start-process-shell-command "tts-synthesis" output-buffer
                         (format "%s %s"
                           (shell-quote-argument script-path)
                           (shell-quote-argument text)))))
      (set-process-query-on-exit-flag process nil))))  ; Prevent "Process running, kill it?" prompts when Emacs exits.


(setq gdp-bash-control-prompt-template "In this conversation, we seek to satisfy the english instruction `<INSTRUCTION>` by executing bash shell script code. In this conversation, you will reply with bash code that I will then execute. I will record the STDOUT and STDERR streams that the code produces and send it back to you. You will consider the outputs and reply with more bash code (if needed) to continue satisfying the instruction. We will iterate together in this fashion - essentially giving you shell access to my computer.

Only reply with bash code. Do not reply with any formatting like backticks. I need to be able to execute what you send me without reformatting or filtering.

Assume that any ambiguous references in the english instruction always resolve to one of: a filename, a directory name, a variable names in file, or a function name in a file. The context of the instruction is the directory named `<DIRECTORY>`. Thus, before writing bash code to fulfill the instruction, you must write bash code to collect enough information to define any ambiguous references in the english instruction. Always assume ambigous references resolve to _something_ - you've just got to collect enough information to figure it out.

After you have fulfilled the instruction, reply in english by writing bash code that echo's the word `REPLY` followed with the reply. Avoid multi-line replies or replies that are very long. I will play back the reply using text to speech software.")


(defun gdp-execute-chatgpt-instructions-new-one (instruction directory)
  (gdp-open-voice-control-window)
  (let ((iteration-counter 0)) ; Declare counter variable
    (cl-labels (
                (handle-reply (bash-code)
                  (when (< iteration-counter 10) ; Check if the counter is less than 10
                    (setq iteration-counter (1+ iteration-counter)) ; Increment counter
                    (gdp-voice-control-log (format "======== bash-code:\n%s" bash-code))
                    (let* ((command-output (shell-command-to-string bash-code))
                           (blah (gdp-voice-control-log command-output))
                           (stdout (if (string-match-p "\\`[ \t\n\r]*\\'" command-output)
                                       "The command did not emit anything."
                                     (string-trim-right command-output "\n"))))
                      (gdp-voice-control-log (format "======== stdout:\n%s" stdout))
                      (if (string-match "REPLY" stdout)
                          (progn
                            (gdp-tts-synthesize-and-play-async (replace-regexp-in-string "REPLY" "" stdout)))
                        (progn
                          (unless (>= iteration-counter 10) ; Check if counter reached 10
                            (gdp-send-single-prompt-to-chatgpt stdout #'handle-reply t)))))))
                )
      (let ((initial-prompt (gdp-multi-replace gdp-bash-control-prompt-template
                                               `(("<INSTRUCTION>" . ,instruction)
                                                 ("<DIRECTORY>" . ,directory)))))
        (gdp-send-single-prompt-to-chatgpt initial-prompt #'handle-reply)))))



;;;;;;;;;;;;;;; voice interface
(defvar gdp-voice-recording-process nil
  "Process handle for the voice recording.")

;;; Define the enhanced `gdp-buffer-context` with an additional `name` field
(cl-defstruct gdp-buffer-context
  name  ; the name of the buffer
  mode  ; the major mode of the buffer
  path  ; the file path associated with the buffer, if any
  region-content)  ; selected text in the buffer, if any

;;; Global variable for storing the last context
(defvar gdp-last-buffer-context nil
  "Global variable to store the last buffer context when `gdp-toggle-voice-recording` is invoked.")

(defun gdp-capture-buffer-context ()
  "Capture current buffer's context including name, major mode, file path, and selected text."
  (interactive)
  (let* ((name (buffer-name))  ; Get the name of the current buffer
         (mode-name (symbol-name major-mode))
         (path (or (buffer-file-name)
                   (and (eq major-mode 'dired-mode) (dired-current-directory))))
         (region-content (when (use-region-p)
                           (buffer-substring-no-properties (region-beginning) (region-end)))))
    ;; Create and set the `gdp-last-buffer-context` with the new `name` field
    (setq gdp-last-buffer-context
          (make-gdp-buffer-context :name name :mode mode-name :path path :region-content region-content))))


(defun gdp-find-newest-audio-file (directory)
  "Find the newest audio file in DIRECTORY."
  (car (last (directory-files directory t "\\.wav$"))))


(defun gdp-toggle-voice-recording ()
  "Toggle voice recording on and off, with buffer context snapshot and Voice Control window message."
  (interactive)
  ;; Make sure the Voice Control window is open and focused
  (gdp-open-voice-control-window)
  (setq gdp-last-buffer-context (gdp-capture-buffer-context))
  (if (process-live-p gdp-voice-recording-process)
      (progn
        ;; Stop recording
        (delete-process gdp-voice-recording-process)
        (setq gdp-voice-recording-process nil)
        (gdp-voice-control-log "Recording stopped. Transcribing...")
        (gdp-transcribe-audio))
    (progn
      ;; Start recording
      (setq gdp-voice-recording-process (start-process "voice-recording" nil "~/voice-interface/start_recording.sh"))
      (gdp-voice-control-log "Started recording."))))

(defun gdp-transcribe-audio ()
  "Transcribe the most recent audio recording."
  (let* ((recording-directory "~/voice-interface/recordings")
         (newest-file (gdp-find-newest-audio-file recording-directory))
         (transcription-command (concat "~/voice-interface/transcribe_audio.sh " newest-file)))
    (gdp-voice-control-log "Sending audio file to the cloud for transcription.")
    (let ((transcription (shell-command-to-string transcription-command)))
      (gdp-voice-control-log (format "Transcription: %s" transcription))
      transcription)))



(defun gdp-transcribe-audio-async (callback)
  "Transcribe the most recent audio recording. Call CALLBACK with transcription when done."
  (let* ((recording-directory "~/voice-interface/recordings")
         (newest-file (gdp-find-newest-audio-file recording-directory))
         (transcription-command (concat "~/voice-interface/transcribe_audio.sh " (shell-quote-argument newest-file))))
    ;; Log that the transcription has started before initiating the async process
    (gdp-voice-control-log "Sending audio file to the cloud for transcription.")
    ;; Start the transcription process with a fresh buffer
    (let* ((transcription-buffer (generate-new-buffer "*Voice Control Transcription*"))
           (transcription-process (start-process-shell-command "transcription-process" transcription-buffer transcription-command)))
      ;; Set the process sentinel, which will call CALLBACK with the transcription result
      (set-process-sentinel transcription-process
                            (lambda (p e)
                              (when (= (process-exit-status p) 0)
                                (with-current-buffer transcription-buffer
                                  (let ((transcription (buffer-string)))
                                    (gdp-voice-control-log (format "Transcription: %s" transcription))
                                    (funcall callback transcription)))
                                (kill-buffer transcription-buffer)))))))

;; (gdp-transcribe-audio-async #'(lambda (text) (message  text)))



;; complete implementation
(defun gdp-run-bash-code-in-buffer-context (bash-code)
  "Run the BASH-CODE in the context of the buffer stored in `gdp-last-buffer-context` and stream output to *Voice Control*."
  (let ((buffer-context gdp-last-buffer-context)
        buffer-name working-directory process)

    ;; Ensure gdp-last-buffer-context is populated and valid
    (unless buffer-context
      (error "No buffer context available"))

    ;; Set the buffer name and working directory from the context
    (setq buffer-name (gdp-buffer-context-name buffer-context))
    (setq working-directory (gdp-buffer-context-path buffer-context))

    ;; Make sure the Voice Control window is open and the buffer is in compilation mode
    (gdp-open-voice-control-window)

    ;; Run the bash code as an asynchronous process within the *Voice Control* buffer
    (setq process
          (start-file-process "voice-control-bash" "*Voice Control*" "bash" "-c" bash-code))

    ;; Configure the process to use the *Voice Control* window, manage its output and highlight errors
    (with-current-buffer "*Voice Control*"
      ;; Note that `compilation-start` was not used, to avoid creating a new compile window.
      (compilation-mode)
      (set (make-local-variable 'compilation-error-regexp-alist) '(bash))
      (set-process-filter process 'compilation-filter))))

(defun gdp-process-transcription-and-send-prompt (transcription)
  "Process the transcription and send a prompt to ChatGPT based on the buffer context."
  (gdp-voice-control-log (format "Transcribed Text: %s" transcription))
  (cond
   ((string= (gdp-buffer-context-mode gdp-last-buffer-context) "dired-mode")
    (gdp-execute-chatgpt-instructions-new-one transcription (gdp-buffer-context-path gdp-last-buffer-context)))
   t (message "not yet supported mode")))



(defun gdp-toggle-voice-recording-and-process ()
  "Toggle voice recording on and off, processing audio and sending prompts to ChatGPT."
  (interactive)
  (gdp-toggle-voice-recording)
  (message "%s" gdp-last-buffer-context)
  (unless (process-live-p gdp-voice-recording-process)
    (gdp-transcribe-audio-async #'(lambda (text) (gdp-process-transcription-and-send-prompt text)))))

;; Keybinding for F12 to toggle voice recording and potentially process commands
(global-set-key (kbd "C-c =") 'gdp-toggle-voice-recording-and-process)





(defun gdp-toggle-voice-recording-and-insert ()
  (interactive)
  (gdp-toggle-voice-recording)
  (message "%s" gdp-last-buffer-context)
  (unless (process-live-p gdp-voice-recording-process)
    (insert (gdp-transcribe-audio))))

(global-set-key (kbd "C-c -") 'gdp-toggle-voice-recording-and-insert)




;; combined ai prompts

(defun gdp-generate-chatgpt-prompt (interpreted-text)
  "Generate a prompt for ChatGPT to create code based on INTERPRETED-TEXT."
  (let ((mode (if gdp-last-buffer-context
                  (gdp-buffer-context-mode gdp-last-buffer-context)
                'unknown))
        (prompt "Please write a "))
    ;; Append to the prompt based on the mode
    (message "%s" (gdp-buffer-context-mode gdp-last-buffer-context))
    (message "mode %s" mode)
    (setq prompt (cond
                  ((eq mode 'dired-mode)
                   (concat prompt "bash script to: " interpreted-text))
                  (t
                   (concat prompt "piece of Emacs Lisp code to: " interpreted-text))))
    ;; Return the full prompt to be sent to ChatGPT
    prompt))

(defun gdp-generate-chatpgt-prompt-bash-code (interpreted-text)
   (format
    "Please respond to the final instruction with only correct bash code. The final instruction is the end of the prompt surrounded by quotes. Do not provide an explanation of the code. Do not surround the code with backticks. Only respond with code that is directly executable with no reformating, filtering, etc. Remember to change directory into the directory `%s`. The final instruction is: \"%s\""
    (gdp-buffer-context-path gdp-last-buffer-context)
    interpreted-text
    ))

(defun gdp-extract-bash-code (input-string)
  "Extracts the bash code blocks from a given multi-line string INPUT-STRING."
  (let ((lines (split-string input-string "\n"))
        (in-bash-block nil)
        (bash-code-blocks '())
        (current-block '()))
    (dolist (line lines)
      (cond
       ((string-match "^```bash" line) (setq in-bash-block t))
       ((string-match "^```" line)
        (when in-bash-block
          (setq bash-code-blocks (append bash-code-blocks (list (string-join current-block "\n"))))
          (setq current-block '()))
        (setq in-bash-block nil))
       (in-bash-block (setq current-block (append current-block (list line))))))
    bash-code-blocks))



(defun gdp-run-bash-code-in-buffer-context (bash-code)
  "Run the BASH-CODE in the context of the buffer stored in `gdp-last-buffer-context` and stream output to *Voice Control*."
  (let ((buffer-context gdp-last-buffer-context)
        buffer-name working-directory process)

    ;; Ensure gdp-last-buffer-context is populated and valid
    (unless buffer-context
      (error "No buffer context available"))

    ;; Set the buffer name and working directory from the context
    (setq buffer-name (gdp-buffer-context-name buffer-context))
    (setq working-directory (gdp-buffer-context-path buffer-context))

    ;; Make sure the Voice Control window is open and the buffer is in compilation mode
    (gdp-open-voice-control-window)

    ;; Set the working directory for the Voice Control buffer
    (with-current-buffer "*Voice Control*"
      (setq default-directory
            (if (file-directory-p working-directory)
                working-directory
              default-directory)))

    ;; Run the bash code as an asynchronous process within the *Voice Control* buffer
    (setq process
          (start-file-process "voice-control-bash" "*Voice Control*" "bash" "-c" bash-code))

    ;; Configure the process to use the *Voice Control* window, manage its output and highlight errors
    (with-current-buffer "*Voice Control*"
      ;; Note that `compilation-start` was not used, to avoid creating a new compile window.
      (compilation-mode)
      (set (make-local-variable 'compilation-error-regexp-alist) '(bash))
      (set-process-filter process 'compilation-filter))))
