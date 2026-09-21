# Etapa 1 — Processamento distribuído de imagens

Processamento em lote de imagens (escala de cinza + blur gaussiano + detecção
de bordas) com versão sequencial e versão paralela (multiprocessing), estado
compartilhado protegido por lock, e provisionamento em nuvem (AWS EC2).

## 1. Ordem de execução (do zero)

```bash
pip install -r requirements.txt

# 1. gerar o dataset de entrada (ajuste --n até o tempo sequencial ficar
python3 generate_dataset.py --n 600 --size 800x600

# 2. rodar sequencial e paralelo separadamente 
python3 sequential.py
python3 parallel.py --workers 8

# 3. provar corretude
python3 verify.py

# 4. provar estabilidade
./run_stability_check.sh 5 8

# 5. benchmark completo
python3 benchmark.py --workers-list 1,2
```

## 2. Credenciais (AWS Academy Learner Lab)

No Academy não existe usuário IAM nem root pra você: as credenciais são
temporárias e vêm prontas do painel do Vocareum.

1. Abra o Learner Lab, clique **Start Lab** e espere o círculo ficar verde.
2. Clique em **AWS Details** (perto do botão Start Lab).
3. Clique em **Show** ao lado de "AWS CLI" — aparece um bloco pronto assim:
   ```
   [default]
   aws_access_key_id=...
   aws_secret_access_key=...
   aws_session_token=...
   ```
4. Cole esse bloco inteiro no arquivo de credenciais do CLI:
   - **PowerShell (Windows):**
     ```powershell
     New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.aws" | Out-Null
     notepad "$env:USERPROFILE\.aws\credentials"
     ```
     Cole o bloco, salve, feche.
   - **Linux/macOS/WSL:**
     ```bash
     mkdir -p ~/.aws && nano ~/.aws/credentials
     ```
5. Define a região (o bloco do Academy não inclui isso):
   ```
   aws configure set region us-east-1
   ```
6. Confirma: `aws sts get-caller-identity` — se voltar um Account ID, tá pronto.

**Atenção com o cronômetro do Lab:** as credenciais expiram (geralmente
poucas horas) e, se você clicar **End Lab** ou o tempo estourar, a AWS
derruba a instância junto. Deixe o Lab **Started** (verde) até terminar a
apresentação, e se as credenciais expirarem no meio do trabalho, repete o
passo 3-4 com um bloco novo.

**Tipo de instância:** confirmado por teste manual nesse Lab: o teto é
`t2.medium` (2 vCPUs) — `t2.large`/`xlarge`/`2xlarge` e toda a família t3
são negados por "explicit deny" na política do Academy. Os scripts já vêm
configurados com `t2.medium`, sem `CpuCredits=unlimited` (esse flag também
é bloqueado). A AMI é buscada dinamicamente (Amazon Linux 2023, owned by
amazon — Academy barra AMI de terceiro como Ubuntu/Canonical). Se o teu
Lab for diferente e liberar mais, teste um tipo por vez direto com `aws
ec2 run-instances` antes de mudar a variável `INSTANCE_TYPE` no script —
economiza tempo em vez de editar e rodar o script inteiro a cada tentativa.

## 3. Provisionar a instância na AWS

**Linux / macOS / WSL / Git Bash:**
```bash
cd provisioning
./aws_provision.sh   # cria SG restrito ao seu IP + sobe a instância
./deploy.sh           # copia o código e instala as dependências
ssh -i sd-etapa1-key.pem ec2-user@<IP_PUBLICO>   # entra na instância pra rodar ao vivo
# ... ao terminar a apresentação:
./teardown.sh          # termina a instância, apaga o SG
```

**Windows (PowerShell nativo, sem WSL nem Git Bash):**
```powershell
cd provisioning
.\aws_provision.ps1
.\deploy.ps1
ssh -i sd-etapa1-key.pem ec2-user@<IP_PUBLICO>
# ... ao terminar a apresentação:
.\teardown.ps1
```
Se o PowerShell recusar rodar o script ("não pode ser carregado porque a
execução de scripts foi desabilitada"), rode uma vez:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```
Isso libera só pra aquela janela de terminal, não mexe em nada permanente.
Precisa também do cliente OpenSSH do Windows (`ssh`/`scp`) — se `ssh -V`
der erro, ative em Configurações > Aplicativos > Recursos opcionais >
Adicionar um recurso > "Cliente OpenSSH".

**Importante:** `nproc` na instância mostra quantos vCPUs tem de verdade —
use esse número como o maior valor de `--workers-list`.

## 4. Calibração do tempo de demo

A apresentação tem só 3 minutos pra "sequencial + paralela rodando com os
tempos aparecendo". Calibre `--n` (número de imagens) e `--blur-passes`
(custo de CPU por imagem, em `processing.py`) para que:

- `T_seq` fique entre 60 e 90s
- `T_par` com 2 processos (o máximo desse Lab) fique visivelmente menor
  (40-55s — com só 2 vCPUs o teto teórico é 2x, não espere mais que isso),
  pra dar tempo de mostrar os dois rodando e ainda sobrar tempo pra falar

Rode `generate_dataset.py` + `sequential.py` uma vez ANTES do dia da
apresentação pra medir e ajustar — não calibre pela primeira vez ao vivo.

## 5. O que cada arquivo prova, na linguagem da rubrica

| Exigência do projeto                          | Onde está                                              |
|------------------------------------------------|---------------------------------------------------------|
| Versão sequencial e paralela do mesmo programa  | `sequential.py` / `parallel.py`, ambos chamam a mesma `process_image()` em `processing.py` |
| Resultado verificável                           | `verify.py` (hash MD5 imagem a imagem)                  |
| Estado compartilhado protegido por lock         | `parallel.py`, `_worker()`: `shared_counter` e `shared_manifest`, protegidos por `multiprocessing.Lock` |
| Processos, não threads (CPU-bound)              | `parallel.py` usa `multiprocessing.Pool` — justificativa no relatório (GIL) |
| Resultado estável em execuções repetidas        | `run_stability_check.sh`                                |
| Medição de desempenho + speedup + Amdahl        | `benchmark.py`                                           |
| Porta administrativa restrita à origem da equipe| `provisioning/aws_provision.sh` (SG só libera 22 pro IP de quem roda o script) |
