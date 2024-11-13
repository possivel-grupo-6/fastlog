# fastlog
Repo para uso do laboratorio do projeto de arquitetura em nuvem

Como usar para o kubernetes

Rodar estes comandos no master para pegar os valores
hash:
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | awk '{print $2}'
Token
kubeadm token create

Rodar este comando no worker
      kubeadm join <ip-masternode>:6443 --token <token> \
	    --discovery-token-ca-cert-hash sha256:<tokenhash> 