
IMAGE_DEV="diegograssato/samba4"
IMAGE_PROD="diegograssato/samba4"
CONATAINER_DEV="samba4"

.PHONY: debug \
	release \
	clean

debug: clean \
	test

test:
	docker build -t $(IMAGE_DEV) --rm .
	docker run --name $(CONATAINER_DEV) --rm --privileged \
		-p 53:53 -p 53:53/udp \
		-p 88:88 -p 88:88/udp -p 135:135 \
		-p 137-138:137-138/udp -p 139:139 \
		-p 389:389 -p 389:389/udp -p 445:445 \
		-p 464:464 -p 464:464/udp -p 636:636 \
		-p 1024-1044:1024-1044 -p 3268-3269:3268-3269 \
		 --cap-add=all  \
		--hostname="ad.dtux.org" \
		--dns-search="dtux.org" \
		-e "SAMBA_DOMAIN"="DTUX" \
		-e "SAMBA_REALM"="DTUX.ORG" \
		-e "SAMBA_ADMIN_PASSWORD"="D13g@anna" \
		-e "ROOT_PASSWORD"="D13g@anna" \
		-e "LDAP_ALLOW_INSECURE"="true" \
		-e "SAMBA_DNS_BACKEND"="BIND9_DLZ" \
		-e "SAMBA_ROLE"="dc" \
		-e "SAMBA_TLS"="false" \
		-e "SAMBA_DHCP"="true" \
		-e "SAMBA_ENABLE_NTP"="false" \
		-e "SAMBA_DNS_REVERSA_ADDR"="0.17.172.in-addr.arpa" \
		-t $(IMAGE_DEV)

release:
	docker build -t $(IMAGE_PROD):$(shell cat VERSION) .
	docker push $(IMAGE_PROD):$(shell cat VERSION)

clean:
	docker stop $(CONATAINER_DEV) || true
	docker rm $(CONATAINER_DEV) || true
