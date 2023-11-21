# Emacs Pinky Saver

This repository serves as a _very simple_ implementation of a voice-driven
GPT4 co-worker for emacs. This is not an emacs package, but rather strung-together
elisp functions and shell scripts that demonstrate how disturbingly trivial it
is to build an emacs AI co-worker. See the [blog
post](https://arrayfire.com/blog/talk-to-emacs-with-a-gpt4-co-worker/) for a
quick writeup. Notably, it was surprisingly [simple to record audio with very
low
latency](https://github.com/pv-pterab-s/emacs-pinky-saver/blob/main/start_recording.sh)
and equally surprisingly [simple to transcribe text with
OpenAI](https://github.com/pv-pterab-s/emacs-pinky-saver/blob/main/transcribe_audio.sh)
as well as [generate speech with
OpenAI](https://github.com/pv-pterab-s/emacs-pinky-saver/blob/main/text-to-speech.sh).

Most surpisingly, however, was how easy it was to define an iterative
algorithm with a simple initial prompt:

    In this conversation, we seek to satisfy the english instruction
    `<INSTRUCTION>` by executing bash shell script code. In this conversation, you
    will reply with bash code that I will then execute. I will record the STDOUT
    and STDERR streams that the code produces and send it back to you. You will
    consider the outputs and reply with more bash code (if needed) to continue
    satisfying the instruction. We will iterate together in this fashion -
    essentially giving you shell access to my computer.

    Only reply with bash code. Do not reply with any formatting like backticks. I
    need to be able to execute what you send me without reformatting or filtering.

    Assume that any ambiguous references in the english instruction always resolve
    to one of: a filename, a directory name, a variable names in file, or a
    function name in a file. The context of the instruction is the directory named
    `<DIRECTORY>`. Thus, before writing bash code to fulfill the instruction, you
    must write bash code to collect enough information to define any ambiguous
    references in the english instruction. Always assume ambigous references
    resolve to _something_ - you've just got to collect enough information to
    figure it out.

    After you have fulfilled the instruction, reply in english by writing bash
    code that echo's the word `REPLY` followed with the reply. Avoid multi-line
    replies or replies that are very long. I will play back the reply using text
    to speech software.

## Setup Sketch

The emacs code is a simple elisp script `ui.el` that depends on an installed
and configured [gptel](https://github.com/karthink/gptel) package. Critically,
`gptel` must be configured to utilize the [gpt-4-1106-preview
model](https://platform.openai.com/docs/models/gpt-4-and-gpt-4-turbo) - an
exclusive model you only have access to if you have paid at least $1 on OpenAI
API charges in the past. This requires forcibly setting the `gptel-model`
variable. We assume that you have a valid OpenAI API key that you must define
in `text-to-speech.sh` and `transcribe_audio.sh` as well as in the `gptel`
configuration. Finally (and horribly) the script is hard-coded to run at
`~/voice-interface`.

Email or file bugs if there are problems. I will formalize this work if there
is interest.

## Usage

`ui.el` defines `C-c =` as a toggle for voice recording. Source the `ui.el`
with `eval-buffer` (after setup as described above). From `dired-mode`, begin
recording with the toggle, make your request, and toggle the recording
again. Once toggled off, emacs will process your voice recording, query the AI
with the initial prompt, above, and start executing the AI's instructions.

**WARNING** The AI can make mistakes and you might say something horrible on
accident like "Man, I hate my harddrive!" I hope you understand the
ramifications :D
