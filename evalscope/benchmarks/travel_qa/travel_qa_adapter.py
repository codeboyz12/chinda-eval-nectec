# Copyright (c) Alibaba, Inc. and its affiliates.
"""
Travel QA Benchmark Adapter

A Thai/English multiple-choice question benchmark focused on travel knowledge
(destinations, accommodations, local culture, attractions). Designed to evaluate
LLMs adapted for the Thai travel domain, e.g. the OpenThaiGPT ThaiLLM family.

The benchmark loads JSONL files in the standard MCQ format:
    {"id": "1", "question": "...", "A": "...", "B": "...", "C": "...", "D": "...", "answer": "B"}

Subsets are resolved as files of the form ``{subset}_{split}.jsonl`` under the
``dataset_id`` directory (which defaults to ``custom_eval/text/mcq``). A small
example subset, ``travel_qa_example``, ships with the repo so the benchmark can
be exercised end-to-end without the proprietary test set.
"""
from evalscope.api.benchmark import BenchmarkMeta, MultiChoiceAdapter
from evalscope.api.dataset import Sample
from evalscope.api.registry import register_benchmark
from evalscope.constants import Tags
from evalscope.utils.logger import get_logger

logger = get_logger()


TRAVEL_QA_PROMPT_TEMPLATE = (
    'Answer the following multiple choice question. Your response should end with '
    'the following format: "ANSWER: LETTER" (without quotes), where LETTER is one of {letters}.\n\n'
    'Question: {question}\nChoices:\n{choices}\n'
)


@register_benchmark(
    BenchmarkMeta(
        name='travel_qa',
        pretty_name='Travel-QA',
        description=(
            'Thai/English multiple-choice questions about travel in Thailand: destinations, '
            'accommodations, attractions, local culture, food, and travel logistics. The '
            'benchmark ships with a small example subset (``travel_qa_example``); the full '
            'test set is provided separately by its owner. See the README for the data layout '
            'and how to point the runner at a private subset.'
        ),
        tags=[Tags.MULTIPLE_CHOICE, Tags.MULTI_LINGUAL, Tags.CUSTOM],
        dataset_id='custom_eval/text/mcq',
        subset_list=['travel_qa_example'],
        metric_list=['acc'],
        few_shot_num=0,
        train_split='dev',
        eval_split='val',
        prompt_template=TRAVEL_QA_PROMPT_TEMPLATE,
    )
)
class TravelQAAdapter(MultiChoiceAdapter):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.choices = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J']

    def load_from_disk(self, **kwargs):
        return super().load_from_disk(use_local_loader=True)

    def record_to_sample(self, record) -> Sample:
        choices = []
        for choice_key in self.choices:
            if choice_key in record:
                choices.append(record[choice_key])
            else:
                break

        return Sample(
            input=record['question'],
            choices=choices,
            target=record['answer'],
            metadata={'id': record.get('id', 'unknown')},
        )
