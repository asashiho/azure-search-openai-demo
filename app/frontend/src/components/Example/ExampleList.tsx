import { Example } from "./Example";

import styles from "./Example.module.css";

export type ExampleModel = {
    text: string;
    value: string;
};

const EXAMPLES: ExampleModel[] = [
    {
        text: "知っている情報を一覧で教えてください",
        value: "知っている情報を一覧で教えてください"
    },
    { 
        text: "プログラムを作成するためのサンプルプロンプトを教えてください", 
        value: "プログラムを作成するためのサンプルプロンプトを教えてください" 
    },
    { 
        text: "エラーメッセージを解析するためのサンプルプロンプトを教えてください", 
        value: "エラーメッセージを解析するためのサンプルプロンプトを教えてください" 
    }
];

interface Props {
    onExampleClicked: (value: string) => void;
}

export const ExampleList = ({ onExampleClicked }: Props) => {
    return (
        <ul className={styles.examplesNavList}>
            {EXAMPLES.map((x, i) => (
                <li key={i}>
                    <Example text={x.text} value={x.value} onClick={onExampleClicked} />
                </li>
            ))}
        </ul>
    );
};
