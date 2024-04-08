import { useState } from "react";
import { Stack, TextField } from "@fluentui/react";
import { Send28Filled } from "@fluentui/react-icons";

import styles from "./QuestionInput.module.css";

interface Props {
    onSend: (question: string) => void;
    disabled: boolean;
    placeholder?: string;
    clearOnSend?: boolean;
}

export const QuestionInput = ({ onSend, disabled, placeholder, clearOnSend }: Props) => {
    const [question, setQuestion] = useState<string>("");
    const [isTyping, setIsTyping] = useState(false);

    const sendQuestion = () => {
        if (disabled || !question.trim()) {
            return;
        }

        onSend(question);

        if (clearOnSend) {
            setQuestion("");
        }
    };

    const onEnterPress = (ev: React.KeyboardEvent<Element>) => {
        if (ev.key === "Enter" && !ev.shiftKey && !isTyping) {
            ev.preventDefault();
            sendQuestion();
        }
    };

    const onQuestionChange = (_ev: React.FormEvent<HTMLInputElement | HTMLTextAreaElement>, newValue?: string) => {
        if (!newValue) {
            setQuestion("");
        } else if (newValue.length <= 1000) {
            setQuestion(newValue);
        }
    };

    const onCompositionStart = () => {
        setIsTyping(true);
    };
    const onCompositionEnd = () => {
        setIsTyping(false);
    };

    const sendQuestionDisabled = disabled || !question.trim();

    return (
        <Stack horizontal className={styles.questionInputContainer}>
            <TextField
                className={styles.questionInputTextArea}
                placeholder={placeholder}
                multiline
                resizable={false}
                borderless
                value={question}
                onChange={onQuestionChange}
                onKeyDown={onEnterPress}
                onCompositionStart={onCompositionStart}
                onCompositionEnd={onCompositionEnd}
            />
            <div className={styles.questionInputButtonsContainer}>
                <div
                    className={`${styles.questionInputSendButton} ${sendQuestionDisabled ? styles.questionInputSendButtonDisabled : ""}`}
                    aria-label="Ask question button"
                    onClick={sendQuestion}
                >
                    <Send28Filled primaryFill="rgba(115, 118, 225, 1)" />
                </div>
            </div>
        </Stack>
    );
};
