# Hidro

App de jejum intermitente e rastreador de água, feita em Flutter.

## Como funciona o build

Este repositório está configurado com **GitHub Actions**
(`.github/workflows/build-apk.yml`): sempre que há código novo enviado para
o ramo `main`, o GitHub compila automaticamente um ficheiro `.apk` que pode
ser descarregado na aba **Actions** do repositório, dentro do separador
**Artifacts** da execução mais recente.

Não é necessário instalar Flutter, Android Studio, ou qualquer outra
ferramenta no computador para gerar o APK — tudo corre na cloud.

## Privacidade

Todos os dados (sessões de jejum, registos de água, definições) são
guardados localmente no telemóvel, através do `shared_preferences`.
Nenhum dado é enviado para qualquer servidor.
