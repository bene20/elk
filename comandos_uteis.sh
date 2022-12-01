#/bin/bash

#####################################
# Índices do Shakespeare
#####################################
#Cria a estrutura do índice no ES
wget http://media.sundog-soft.com/es7/shakes-mapping.json -O material_baixado/shakes-mapping.json
curl -H 'Content-Type: application/json' -XPUT http://127.0.0.1:9200/shakespeare --data-binary @material_baixado/shakes-mapping.json

#Realiza a indexação do documento do Shakespeare
wget http://media.sundog-soft.com/es7/shakespeare_7.0.json -O material_baixado/shakespeare_7.0.json
curl -H 'Content-Type: application/json' -XPOST http://127.0.0.1:9200/shakespeare/_bulk?pretty --data-binary @material_baixado/shakespeare_7.0.json

#Realiza a pesquisa do termo 'to be or not to be' na obra indexada
curl -H 'Content-Type: application/json' -XGET http://127.0.0.1:9200/shakespeare/_search?pretty -d '{"query":{"match_phrase":{"text_entry":"to be or not to be"}}}'


#####################################
# Índices do filme
#####################################

#Cria a estrutura do índice movies no ES
./mycurl.sh -XPUT 127.0.0.1:9200/movies -d '{"mappings":{"properties":{"year":{"type":"date"}}}}'

#Checa se a estrutura do índice foi criada corretamente
./mycurl.sh -XGET 127.0.0.1:9200/movies

#Adiciona um filme no índice (escolhi o ID 109487 para o regitro. Se não escolher um, o ES atribuirá um automaticamente)
./mycurl.sh -XPOST 127.0.0.1:9200/movies/_doc/109487 -d '{"genre":["IMAX","Sci-Fi"],"title":"Interestellar","year":2014}'

#Pesquisa os filmes registrados no índice
./mycurl.sh -XGET 127.0.0.1:9200/movies/_search?pretty

#Adição de filmes em lote no índice
wget http://media.sundog-soft.com/es7/movies.json -O material_baixado/movies.json
./mycurl.sh -XPUT http://127.0.0.1:9200/_bulk?pretty --data-binary @material_baixado/movies.json

#Altera o registro do filme 109487 adicionado acima (Todos os dados devem ser informados novamente, o ES cria um novo registro com uma nova versão do documento)
./mycurl.sh -XPUT 127.0.0.1:9200/movies/_doc/109487 -d '{"genre":["IMAX","Sci-Fi"],"title":"Interstellar","year":2014}'

#Altera o título do filme de id 1924 para 'Interestelar foo'
./mycurl.sh -XPOST 127.0.0.1:9200/movies/_doc/109487/_update -d '{"doc":{"title":"Interestelar foo"}}'

#Pesquisa um documento específico de id 109487
./mycurl.sh -XGET 127.0.0.1:9200/movies/_doc/109487?pretty

#Query por um registro
./mycurl.sh -XGET 127.0.0.1:9200/movies/_search?q=Dark

#Excluindo o registro de ID 58559
./mycurl.sh -XDELETE 127.0.0.1:9200/movies/_doc/58559

#Atualização evitando problema de concorrência: restringindo a atualização ao controle de shard e de sequência
./mycurl.sh -XPUT "127.0.0.1:9200/movies/_doc/109487?if_seq_no=7&if_primary_term=1" -d '{"genre":["IMAX","Sci-Fi"],"title":"Interestellar","year":2014}'

#Atualização evitando problema de concorrência e deixando o ES tentar novamente em caso de conflito do controle de sequência e/ou shard
./mycurl.sh -XPOST 127.0.0.1:9200/movies/_doc/109487/_update?retry_on_conflict=5 -d '{"doc":{"title":"Interestellartypo"}}'

#Cria a estrutura do índice series como um índice pai do índice movies no ES
./mycurl.sh -XPUT 127.0.0.1:9200/series -d '{"mappings":{"properties":{"film_to_franchise":{"type":"join","relations":{"franchise":"film"}}}}}'

#Adição de series em lote no índice
wget http://media.sundog-soft.com/es7/series.json -O material_baixado/series.json
./mycurl.sh -XPUT http://127.0.0.1:9200/_bulk?pretty --data-binary @material_baixado/series.json

#Fazendo consulta dos filmes filhos associados a um determinado pai (no caso, dos filmes associados à série 'Star Wars')
./mycurl.sh -XGET 127.0.0.1:9200/series/_search?pretty -d '{"query":{"has_parent":{"parent_type":"franchise","query":{"match":{"title":"Star Wars"}}}}}'

#Fazendo consulta para descobrir qual é o pai de um determinado filho (no caso, qual a série do filme 'The Force Awakens')
./mycurl.sh -XGET 127.0.0.1:9200/series/_search?pretty -d '{"query":{"has_child":{"type":"film","query":{"match":{"title":"The Force Awakens"}}}}}'

#ReCria a estrutura do índice movies no ES, usando o subcampo raw para ordenar o campo texto title
./mycurl.sh -XDELETE 127.0.0.1:9200/movies
./mycurl.sh -XPUT 127.0.0.1:9200/movies -d '{"mappings":{"properties":{"title":{"type":"text","fields":{"raw":{"type":"keyword"}}}}}}'
./mycurl.sh -XPUT http://127.0.0.1:9200/_bulk?pretty --data-binary @material_baixado/movies.json

#Pesquisa no índice ordenando a resposta pelo título (pelo subcampo title.raw)
./mycurl.sh -XGET http://127.0.0.1:9200/movies/_search?sort=title.raw

# Aula 54 - Baixando o índice de filmes (com muito mais filmes, para processamento via script python)
wget http://files.grouplens.org/datasets/movielens/ml-latest-small.zip -O material_baixado/ml-latest-small.zip
wget http://media.sundog-soft.com/es7/MoviesToJson.py -O material_baixado/MoviesToJson.py
python3 MoviesToJson.py > moremovies.json
./mycurl.sh -XDELETE 127.0.0.1:9200/movies
./mycurl.sh -XPUT http://127.0.0.1:9200/_bulk?pretty --data-binary @material_baixado/moremovies.json
./mycurl.sh -XGET 127.0.0.1:9200/movies/_search?q=mary%20poppins&pretty=true

# Aula 55 - Processamento via biblioteca)
wget http://media.sundog-soft.com/es7/IndexRatings.py -O material_baixado/IndexRatings.py
pip3 install Elasticsearch==7.7.0
./mycurl.sh -XGET '127.0.0.1:9200/ratings/_search'
./mycurl.sh -XGET '127.0.0.1:9200/ratings/_search' -d '{"aggs":{"ratings":{"terms":{"field":"rating"}}}}'
./mycurl.sh -XGET '127.0.0.1:9200/ratings/_search' -d '{"aggs":{"ratings":{"terms":{"field":"rating"}}}}' | jsonpath -j '$.aggregations.ratings.buckets[?(@.key=5.0)]'
./mycurl.sh -XGET "127.0.0.1:9200/ratings/_search" -d '{"query":{"match":{"rating":5.0}},"aggs":{"ratings":{"terms":{"field":"rating"}}}}' | jq '.aggregations'
./mycurl.sh -XGET "127.0.0.1:9200/ratings/_search" -d '{"query":{"match_phrase":{"title":"Star Wars Episode IV"}},"aggs":{"avg_rating":{"avg":{"field":"rating"}}}}'  | jq '.aggregations'

#####################################
# Tópicos no Logstash
#####################################

# Logstash - Baixando arquivo de log para análise pelo logstash
wget http://media.sundog-soft.com/es/access_log -O material_baixado/access_log

# Listando os índices criados no Elasticsearch
./mycurl.sh -XGET 127.0.0.1:9200/_cat/indices?v

# Consultando o índices criado, na aula 59, no Elasticsearch
./mycurl.sh -XGET 127.0.0.1:9200/logstash-2022.11.22-000001/_search | jq

# Logstash - Baixando arquivo csv e seu respectivo conf para análise pelo logstash
wget https://raw.githubusercontent.com/coralogix-resources/elk-course-samples/master/csv-schema-short-numerical.csv -O material_baixado/csv-schema-short-numerical.csv
wget https://raw.githubusercontent.com/coralogix-resources/elk-course-samples/master/csv-read.conf -O material_baixado/csv-read.conf
wget https://raw.githubusercontent.com/coralogix-resources/elk-course-samples/master/csv-read-drop.conf -O material_baixado/csv-read-drop.conf

# Logstash - Baixando arquivo json para análise pelo logstash
wget http://media.sundog-soft.com/es/sample-json.log -O material_baixado/sample-json.log
wget http://media.sundog-soft.com/es/sample-json-split.log -O material_baixado/sample-json-split.log

# Aula 65 - recriando o índice ratings para funcionar agregações
#./mycurl.sh -XDELETE 127.0.0.1:9200/ratings
./mycurl.sh -XPUT 127.0.0.1:9200/ratings -d '{"mappings":{"properties":{"title":{"type":"text","fields":{"raw":{"type":"keyword"}}}}}}'
