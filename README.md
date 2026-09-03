# Demonstração dos hooks do GitHub Copilot

Este repositório demonstra todos os eventos de hooks atualmente documentados
para o GitHub Copilot. A configuração fica em
`.github/hooks/log-all-events.json` e usa nomes de eventos em camelCase.

Cada hook envia seu payload JSON inalterado aos scripts pelo `stdin` e passa o
nome do evento como primeiro argumento. As implementações equivalentes estão
em `.github/scripts/log-copilot-hook.ps1` e
`.github/scripts/log-copilot-hook.sh`. Cada execução acrescenta um registro ao
arquivo `.github/logs/copilot-hooks.jsonl`, sem produzir saída em `stdout` nem
retornar decisões que interfiram no Copilot.

O arquivo JSONL pode conter prompts, argumentos e resultados de ferramentas,
além de mensagens de erro e outros dados sensíveis. Ele é ignorado pelo Git,
não deve ser publicado e este padrão de registro indiscriminado não deve ser
usado em produção.

Alguns eventos só são disparados por ações específicas. A disponibilidade e o
comportamento dos eventos também podem variar entre o Copilot CLI e o Copilot
cloud agent; por isso, execute esta demonstração preferencialmente com o
GitHub Copilot CLI.

## Como testar

Os hooks deste repositório são carregados pelo GitHub Copilot CLI e pelo
Copilot cloud agent. Apenas abrir o Copilot Chat no VS Code e enviar mensagens
não testa esta configuração. O terminal integrado do VS Code pode ser usado,
mas é necessário iniciar o GitHub Copilot CLI na raiz do repositório:

```powershell
copilot
```

Depois de alterar a configuração, inicie uma nova sessão do CLI. Em outro
terminal do Windows, acompanhe os registros conforme forem criados:

```powershell
Get-Content .github\logs\copilot-hooks.jsonl -Wait
```

Use os exemplos abaixo dentro da sessão do Copilot CLI:

1 - Para disparar normalmente `userPromptSubmitted`, `userPromptTransformed` e
`agentStop`, use o seguinte prompt:

```text
Explique em uma frase qual é o objetivo deste repositório.
```

2 - Para disparar `preToolUse` e `postToolUse`, use o seguinte prompt:

```text
Liste os arquivos deste repositório e leia o README.md.
```

3 - Para tentar disparar `permissionRequest`, use o seguinte prompt:

```text
Crie um arquivo chamado teste-permissao.txt com o texto "teste de hook".
```

A solicitação depende das regras de permissão e das aprovações já concedidas na
sessão.

4 - Para disparar `subagentStart` e `subagentStop`, use o seguinte prompt:

```text
Use um subagente para analisar este README e resumir os principais pontos.
```

Esses eventos serão disparados quando o CLI decidir executar a tarefa por meio
de um subagente.

5 - Para disparar `preCompact`, execute:

```text
/compact
```

6 - Para disparar `sessionEnd`, encerre o CLI executando:

```text
/exit
```

Também é possível encerrar o CLI com `Ctrl+C`.

Eventos como `errorOccurred`, `postToolUseFailure` e `notification` dependem de
condições específicas e podem não aparecer em uma execução normal. Agrupe os
registros de uma mesma conversa pelo campo `payload.sessionId`; use
`payload.timestamp` para ordená-los pelo instante em que o Copilot gerou cada
evento.

Consulte a
[referência oficial de hooks](https://docs.github.com/en/copilot/reference/hooks-reference)
para detalhes dos eventos e payloads.
