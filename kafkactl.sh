set -e


if ! [ -z ${KUBERNETES_SERVICE_HOST+x} ]; then
    kill -9 $(pidof ./jdk-17.0.7+7/bin/java) || true
    rm -rf /tmp/jdk-17.0.7+7 || true
    rm -f kafdrop.jar || true
    rm -f jdk17.tgz || true
    cd /tmp
    curl -Lo jdk17.tgz https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.7%2B7/OpenJDK17U-jdk_x64_linux_hotspot_17.0.7_7.tar.gz
    tar -xvzf jdk17.tgz
    curl -Lo kafdrop.jar https://github.com/vimil-saju/otel-protoc/releases/download/1.0.0/kafdrop-4.0.0.jar
    curl -Lo otel.desc https://github.com/vimil-saju/otel-protoc/raw/main/otel.desc
    ./jdk-17.0.7+7/bin/java --add-opens=java.base/sun.nio.ch=ALL-UNNAMED -jar kafdrop.jar --kafka.brokerConnect=$1 --protobufdesc.directory=/tmp > /dev/null 2> /dev/null &
else
    read -p "Namespace: " namespace
    pods=( $(kubectl get pods --template '{{range .items}}{{.metadata.name}}{{" "}}{{end}}' -n $namespace) )
    
    echo "Select Pod"
    select pod in "${pods[@]}"
    do break;
    done

    containers=( $(kubectl get pod $pod -o jsonpath="{.spec['containers'][*].name}" -n $namespace) )
    echo "Select Container"
    select container in "${containers[@]}"
    do break;
    done

   read -p "Brokers(Press Enter to use default brokers): " brokers
   brokers=${brokers:-b-1.mdasprovamrmskgreened.q8fe1v.c10.kafka.us-east-1.amazonaws.com:9094,b-3.mdasprovamrmskgreened.q8fe1v.c10.kafka.us-east-1.amazonaws.com:9094,b-2.mdasprovamrmskgreened.q8fe1v.c10.kafka.us-east-1.amazonaws.com:9094}
   echo "Brokers: $brokers"

    pkill -f "port-forward pods/$pod 9000:9000 -n $namespace" || true
    kubectl cp $0 $namespace/$pod:/tmp/kafkactl.sh -c $container
    kubectl exec $pod -n $namespace -c $container -- /bin/bash -c "/tmp/kafkactl.sh $brokers"
    kubectl port-forward pods/$pod 9000:9000 -n $namespace &
    /usr/bin/open -a "/Applications/Google Chrome.app" 'http://localhost:9000'
fi   

### Otel Protobuf MessagTypes ###
## Trace --> opentelemetry.proto.trace.v1.TracesData
