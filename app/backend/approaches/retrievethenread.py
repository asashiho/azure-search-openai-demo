from typing import Any

import openai
from azure.search.documents.aio import SearchClient
from azure.search.documents.models import QueryType

from approaches.approach import AskApproach
from core.messagebuilder import MessageBuilder
from text import nonewlines

# ------------------------COSMOSDBロギング用追加:start------------------------
from approaches.chatlogging import write_chatlog, ApproachType
# ------------------------------------end-------------------------------------

class RetrieveThenReadApproach(AskApproach):
    """
    Cognitive SearchとOpenAIのAPIを直接使用した、シンプルなretrieve-then-readの実装です。まず検索から上位のドキュメントを取得し、それを使ってプロンプトを作成し、回答を生成します。
    """

    system_chat_template = \
"あなたは、ChatGPTにおけるプロンプトの書き方や業務効率化に関する質問をサポートするインテリジェントアシスタントです。 " + \
"相手が「わたし」で質問しても、「あなた」を使って質問者を指してください。" + \
"以下の資料に記載されているデータのみを使って、質問に答えてください。" + \
"表形式の情報については、HTMLとして返してください。マークダウン形式は返さないでください。"  + \
"各出典元には、名前の後にコロンが続き、実際の情報が記載されています。回答で使用する各事実には、必ず出典元名を記載してください。" + \
"以下の資料で答えられない場合は、「わからない」と答えなさい。以下の例を使って答えてください。"

    #shots/sample conversation
    question = """
'ChatGPTでどのようなことができますか？'

Sources:
info1.txt: 様々な業務を効率化することができる。例えば、文章添削やプログラムの作成などを支援できる。
info2.txt: ChatGPTに作業を依頼する場合は、実現したい内容の他に、前提条件を具体的に示すことが重要。
"""
    answer = "例えば、文章添削やプログラムの作成[info1.txt]などを支援できます。作業を依頼する際は、実現したい内容の他に、前提条件を具体的に示すことが重要です[info2.txt] "

    def __init__(self, search_client: SearchClient, openai_deployment: str, chatgpt_model: str, embedding_deployment: str, sourcepage_field: str, content_field: str):
        self.search_client = search_client
        self.openai_deployment = openai_deployment
        self.chatgpt_model = chatgpt_model
        self.embedding_deployment = embedding_deployment
        self.sourcepage_field = sourcepage_field
        self.content_field = content_field

    # ------------------------COSMOSDBロギング用追加:start------------------------
    # user_nameを引数に追加
    async def run(self,user_name:str, q: str, overrides: dict[str, Any]) -> Any:
    # ------------------------------------end-------------------------------------
        has_text = overrides.get("retrieval_mode") in ["text", "hybrid", None]
        has_vector = overrides.get("retrieval_mode") in ["vectors", "hybrid", None]
        use_semantic_captions = True if overrides.get("semantic_captions") and has_text else False
        top = overrides.get("top") or 3
        exclude_category = overrides.get("exclude_category") or None
        filter = "category ne '{}'".format(exclude_category.replace("'", "''")) if exclude_category else None

        # If retrieval mode includes vectors, compute an embedding for the query
        if has_vector:
            query_vector = (await openai.Embedding.acreate(engine=self.embedding_deployment, input=q))["data"][0]["embedding"]
        else:
            query_vector = None

        # Only keep the text query if the retrieval mode uses text, otherwise drop it
        query_text = q if has_text else ""

        # Use semantic ranker if requested and if retrieval mode is text or hybrid (vectors + text)
        if overrides.get("semantic_ranker") and has_text:
            r = await self.search_client.search(query_text,
                                          filter=filter,
                                          query_type=QueryType.SEMANTIC,
                                          query_language="en-us",
                                          query_speller="lexicon",
                                          semantic_configuration_name="default",
                                          top=top,
                                          query_caption="extractive|highlight-false" if use_semantic_captions else None,
                                          vector=query_vector,
                                          top_k=50 if query_vector else None,
                                          vector_fields="embedding" if query_vector else None)
        else:
            r = await self.search_client.search(query_text,
                                          filter=filter,
                                          top=top,
                                          vector=query_vector,
                                          top_k=50 if query_vector else None,
                                          vector_fields="embedding" if query_vector else None)
        if use_semantic_captions:
            results = [doc[self.sourcepage_field] + ": " + nonewlines(" . ".join([c.text for c in doc['@search.captions']])) async for doc in r]
        else:
            results = [doc[self.sourcepage_field] + ": " + nonewlines(doc[self.content_field]) async for doc in r]
        content = "\n".join(results)

        message_builder = MessageBuilder(overrides.get("prompt_template") or self.system_chat_template, self.chatgpt_model)

        # add user question
        user_content = q + "\n" + f"Sources:\n {content}"
        message_builder.append_message('user', user_content)

        # Add shots/samples. This helps model to mimic response and make sure they match rules laid out in system message.
        message_builder.append_message('assistant', self.answer)
        message_builder.append_message('user', self.question)

        messages = message_builder.messages
        chat_completion = await openai.ChatCompletion.acreate(
            deployment_id=self.openai_deployment,
            model=self.chatgpt_model,
            messages=messages,
            temperature=overrides.get("temperature") or 0.3,
            max_tokens=1024,
            n=1)

        # ------------------------COSMOSDBロギング用追加:start------------------------
        total_tokens = chat_completion.usage.total_tokens
        ask_content = chat_completion.choices[0].message.content

        write_chatlog(ApproachType.Ask, user_name, total_tokens, "", ask_content, query_text)
        # ------------------------------------end-------------------------------------

        return {"data_points": results, "answer": chat_completion.choices[0].message.content, "thoughts": f"Question:<br>{query_text}<br><br>Prompt:<br>" + '\n\n'.join([str(message) for message in messages])}
