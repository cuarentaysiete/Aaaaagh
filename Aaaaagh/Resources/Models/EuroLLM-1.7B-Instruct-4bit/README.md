# Bundled model: EuroLLM-1.7B-Instruct-4bit

This directory contains the **metadata** for the bundled translator model
(config, tokenizer, chat template). The large weight file (`model.safetensors`,
~930 MB) is **not committed** to this repository to keep the clone small.

To make the app functional, place the weight file here:

```
Aaaaagh/Resources/Models/EuroLLM-1.7B-Instruct-4bit/
├── config.json
├── generation_config.json
├── chat_template.jinja
├── tokenizer.json
├── tokenizer_config.json
├── model.safetensors.index.json
└── model.safetensors          <- ADD THIS (download, ~930 MB)
```

## How to obtain the weights

The model you provided already has the file at:

```
<your machine>/model/dreamer1cc/EuroLLM-1.7B-Instruct-4bit/model.safetensors
```

Copy it into this folder:

```bash
cp /path/to/model/dreamer1cc/EuroLLM-1.7B-Instruct-4bit/model.safetensors \
   Aaaaagh/Resources/Models/EuroLLM-1.7B-Instruct-4bit/
```

Or, if you want the app to use a model that already lives on disk instead of the
bundled copy, open **Model Settings** in the app and pick that folder — the
`LocalModelScanner` validates it and the app will use it. The bundled folder is
only a convenience default.

## Validation

The app checks for these files on startup (see `LocalModelScanner`):
`config.json`, a `model*.safetensors` weight file, and a tokenizer
(`tokenizer.json` or `tokenizer.model`). Until all are present the UI panes
stay greyed out.
