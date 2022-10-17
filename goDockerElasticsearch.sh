#!/bin/bash

#set -x #Descomentar esta linha para debugar este script

nomerede=netbn
elasticsearchcontainername=elasticsearchbn
portElasticSearch=9200 # Usada para chamadas à API do elasticsearch via protocolo HTTP
container=$elasticsearchcontainername
exposePort=$portElasticSearch
imagem=elasticsearchbn:1.0

urlServico=http://127.0.0.1:$exposePort

sep="================================================"

simOuNao(){
  select sn in "Sim" "Não"; do
    case $sn in
      Sim ) return 0;;
      Não ) return 1;;
    esac
  done
  echo
}

testaComando(){
  comando="$1"
  command -v $comando >/dev/null 2>&1
  ret=$?
  if [ $ret -eq 1 ]; then
    echo "'$comando' não está instalado. Abortar."
    exit 1
  fi
}

testaComando jq

_waitService(){
  echo $sep
  echo -en "\n\nAguardando carregamento de serviço em ${urlServico}: "
  rc=0
  while [ $rc -eq 0 ]; do
    echo -n "."
    #Checando se a url informada na resposta de redirecionamento acima está acessível
    rc=$(curl -s --head --request GET ${urlServico} | head -n 1 | grep "200 OK" | wc -l)
    sleep 1
  done
  echo "OK!"
  echo "Serviço de pé e pronto para uso!"
  echo
}

_removeContainer(){
  docker container rm -f -v ${container} > /dev/null 2>&1
}

_removeVolumes(){
  echo "Não há volumes a serem removidos para este container"
}

_removeImage(){
  docker image rm $(docker image ls | grep none | awk '{print $3}') > /dev/null 2>&1
  docker image rm -f ${imagem} > /dev/null 2>&1
  docker image rm $(docker image ls | grep none | awk '{print $3}') > /dev/null 2>&1
}

_removeNetwork(){
  if [ $(docker network ls | grep $nomerede | wc -l) -gt 0 ]; then
    docker network rm $nomerede > /dev/null 2>&1

    if [ $? -ne 0 ]; then
      echo "ATENÇÃO: não foi possível remover a rede '$nomerede'. Veja abaixo a relação dos containers ainda conectados a ela:"
      docker network inspect ${nomerede} | jq -r 'map(.Containers[].Name) []'
      echo
    else
      echo "Rede privada '$nomerede' removida com sucesso."
      echo
    fi
  fi
}

_push(){
  _checaLoginRegistry
  imageID=$(docker image ls -q --filter reference="${imagem}")
  tagname=$(echo $imagem | sed "s/:[^:]*$/:${tagToPush}/g")
  if [ -z "${imageID}" ] || [ -z "${tagname}" ]; then
    echo "Não foi possível determinar o ID da imagem (${imageID}) ou a tag a ser aplicada (${tagname})"
  else
    echo "Aplicando tag: 'docker image tag ${imageID} ${tagname}'"
    docker image tag ${imageID} ${tagname}
    docker push ${tagname}

    if [ $? -ne 0 ]; then
      echo "Erro no push da imagem ${tagname} (ID ${imageID})"
      exit 1
    else
      echo "Push da imagem ${tagname} (ID ${imageID}) feito com sucesso!"
    fi
  fi
}

build(){
  _build
  exit
}

runDock(){
  _runDock
  exit
}

_stopDock(){
  docker container stop ${container} > /tmp/resp_stop 2>&1
  [ $? != 0 ] || cat /tmp/resp_stop
  rm -f /tmp/resp_stop
}

stopDock(){
  _stopDock
  echo
  exit
}

_execDock(){
  docker container exec -it ${container} /bin/bash
}

_conectarRede(){
  if [ $(docker network ls | grep $nomerede | wc -l) -eq 0 ]; then
    docker network create $nomerede
  
    if [ $? -ne 0 ]; then
      echo "Erro ao tentar criar rede '$nomerede' para os containers"
      exit 1
    fi
    
    echo "Criada rede docker privada '$nomerede'"
  fi

  docker network connect $nomerede $container

  if [ $? -ne 0 ]; then
    echo "Erro ao tentar conectar container '$container' na rede '$nomerede'"
    exit 1
  fi

  echo "Container '$container' conectado à rede '$nomerede'"
}

_checaElasticSearch(){
  if ! $(docker network inspect $nomerede | jq -r 'map(.Containers[].Name) []' | grep -q $elasticsearchcontainername); then
    echo "Container do ElasticSearch não encontrado na rede '$nomerede'. Provavelmente ele não está carregado. Abortando!!"
    exit 1
  fi
}

execDock(){
  _execDock
  exit
}

_viewLogsContainer(){
  reset; docker logs -f ${container}
}

viewLogsContainer(){
  _viewLogsContainer
  exit
}

buildRun(){
  _build
  _runDock
  exit
}

buildRunExec(){
  _build
  _runDock
  _execDock
  exit
}

push(){
  _push
  exit
}

buildPush(){
  _build
  _push
  exit
}

_cleanAll(){
 _stopDock
 _removeContainer
 _removeVolumes
 _removeImage
 _removeNetwork
}

cleanAll(){
  _cleanAll
  exit
}

checkEnv(){
  echo -e "$sep\nContainers:"; docker container ls -a
  echo -e "$sep\nVolumes:"; docker volume ls 
  echo -e "$sep\nImages:"; docker image ls 
  echo -e "$sep\nRedes:"; docker network ls 
  exit
}

criaIndice(){
  curl -H 'Content-Type: application/json' -XPUT ${urlServico}/shakespeare --data-binary @material_baixado/shakes-mapping.json
  exit
}

indexaShakespeare(){
  curl -H 'Content-Type: application/json' -XPOST ${urlServico}/shakespeare/_bulk?pretty --data-binary @material_baixado/shakespeare_7.0.json
  exit
}

_checaLoginRegistry(){
  if [ ! -f "$HOME/.docker/config.json" ] || \
     [ $(cat "$HOME/.docker/config.json" | grep ${registrytrt10} | wc -l) -eq 0 ]; then 
    echo "Não existe uma sessão aberta com o registry '${registrytrt10}'."
    echo "Para resolver isso execute o comando abaixo e informe suas credenciais quando solicitado."
    echo "   docker login ${registrytrt10}"
    exit 1
  fi
}
_removeVolumes(){
  docker volume rm elasticsearch-data > /dev/null 2>&1
}

_build(){
  docker image build --force-rm -t ${imagem} \
         -f Dockerfile.elasticsearch .

  if [ $? -ne 0 ]; then
    echo "Erro no build da imagem"
    exit 1
  fi
}

_runDock(){
  _stopDock

  echo "Subindo o serviço na porta ${exposePort}"
  echo "Obs: O container está subindo em modo daemon. Nenhum log será exibido."

  docker container run -d --rm --name ${container} \
         -p $exposePort:9200 \
         --ulimit memlock=-1:-1 \
         --ulimit nofile=65535:65535 \
         --ulimit nproc=4096:4096 \
         -v elasticsearch-data:/usr/share/elasticsearch/data \
         ${imagem} 

  if [ $? -ne 0 ]; then
    echo "Erro ao tentar subir o container"
    exit 1
  fi

  _conectarRede
  _waitService
}

menu(){
  op=$1

  case $op in
    Build              ) build;;
    Run                ) runDock;;
    Stop               ) stopDock;;
    Exec               ) execDock;;
    BuildRun           ) buildRun;;
    BuildRunExec       ) buildRunExec;;
    Push               ) push;;
    BuildPush          ) buildPush;;
    ViewLogsContainer  ) viewLogsContainer;;
    CleanAll           ) cleanAll;;
    CheckEnv           ) checkEnv;;
    CriaIndice         ) criaIndice;;
    IndexaShakespeare  ) indexaShakespeare;;
    Quit               ) exit;;
  esac
}

operacao="$1"
echo -e "\n${sep}"
echo "BACKEND ELASTICSEARCH"
echo -e "${sep}\n"

if [ -z "${operacao}" ]; then
  echo "Escolha uma das seguintes opções:"
  select op in "Build" "Run" "Stop" "Exec" "BuildRun" "BuildRunExec" "Push" "BuildPush" "ViewLogsContainer" "CleanAll" "CheckEnv" "CriaIndice" "IndexaShakespeare" "Quit"; do
    menu $op
  done
else
    echo "Executando operação '${operacao}'."
    menu ${operacao}
    echo "Operação '${operacao}' inválida!"
fi
