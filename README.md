# TD2 - Terraform : Filtrage Entrant (Bastion), Filtrage Sortant (NAT) et Sonde Suricata

**Étudiant :** RAVEENDRAKUMAR Arusan   
**Cours :** Terraform / AWS  
**Date :** Juin 2026  

## Objectif du TD

Mettre en place une architecture AWS sécurisée avec Terraform permettant de démontrer :

- **Filtrage entrant** : Accès SSH restreint via un bastion
- **Filtrage sortant** : Instances dans un sous-réseau privé utilisant un NAT Gateway pour accéder à Internet
- **Sonde de détection** : Instance Suricata avec règles personnalisées

Région utilisée : `eu-west-3` (Paris)  
VPC : VPC par défaut AWS

## Architecture

```
                    Internet
                        |
                        v
                [Bastion Public]
                - SSH uniquement depuis mon IP
                - SG : td2-42-sg-bastion
                        |
          +-------------+-------------+
          |                           |
   [NAT Gateway]               [Sonde Suricata]
   - EIP + NAT                 - Ubuntu + Suricata
   - td2-42-nat                - Règle ICMP "TD2 ICMP detecte"
          |                    - td2-42-sonde
          v
   [Sous-réseau Privé]
   - td2-42-prive (172.31.240.0/24)
   - Instance privée (Amazon Linux)
   - Accès sortant via NAT uniquement
   - SSH uniquement depuis le bastion
```

## Ressources déployées

| Ressource              | Nom                          | Description                          |
|------------------------|------------------------------|--------------------------------------|
| EC2 Instance           | td2-42-bastion               | Bastion public (filtrage entrant)    |
| EC2 Instance           | td2-42-prive                 | Instance dans le sous-réseau privé   |
| EC2 Instance           | td2-42-sonde                 | Sonde Suricata                       |
| Security Group         | td2-42-sg-bastion            | SSH depuis mon IP uniquement         |
| Security Group         | td2-42-sg-prive              | SSH depuis bastion uniquement        |
| Security Group         | td2-42-sg-sonde              | SSH + ICMP depuis bastion            |
| Subnet                 | td2-42-prive                 | Sous-réseau privé                    |
| NAT Gateway            | td2-42-nat                   | Passerelle NAT                       |
| Elastic IP             | td2-42-eip-nat               | IP publique pour le NAT              |
| Route Table            | td2-42-rt-prive              | Routage vers NAT                     |

## Fichiers du projet

- `provider.tf` — Configuration du provider AWS (eu-west-3)
- `variables.tf` — Déclaration des variables (`student_id`, `my_ip`, `key_name`)
- `data.tf` — Data sources (VPC par défaut, sous-réseaux publics, AMIs)
- `bastion.tf` — Ressources du bastion + Security Group
- `egress.tf` — Sous-réseau privé, NAT Gateway, routage (filtrage sortant)
- `suricata.tf` — Sonde Suricata avec `user_data` pour l'installation et la règle custom
- `terraform.tfvars` — Valeurs personnelles (student_id = 42)
- `.gitignore` — Exclusion des états Terraform

## Déploiement

```bash
# Initialisation
terraform init

# Planification
terraform plan

# Déploiement
terraform apply
```

## Outputs

```hcl
bastion_ip       = "13.38.12.53"
private_ip       = "172.31.240.162"
sonde_public_ip  = "51.44.183.133"
sonde_private_ip = "172.31.107.75"
```

## Tests

### 1. Connexion au bastion

```powershell
ssh -i "$env:USERPROFILE\.ssh\td2-42-key.pem" ec2-user@13.38.12.53
```

### 2. Connexion à la sonde Suricata (depuis le bastion)

```bash
# Depuis le bastion
ssh -i ~/td2-42-key.pem ubuntu@172.31.107.75
```

### 3. Test de détection Suricata

**Sur la sonde (dans un terminal) :**

```bash
sudo tail -f /var/log/suricata/fast.log
```

**Depuis le bastion (dans un autre terminal) :**

```bash
ping -c 5 172.31.107.75
```

Vérifier l'apparition de l'alerte :

```
[**] [1:1000001:1] TD2 ICMP detecte [**]
```

### Commandes utiles sur la sonde

```bash
# Statut
sudo systemctl status suricata

# Logs détaillés
sudo tail -f /var/log/suricata/eve.json

# Règles
grep -i "TD2" /var/lib/suricata/rules/suricata.rules
```

## Captures d'écran des tests

Les captures suivantes (en PNG) montrent les tests réalisés en PowerShell pour valider le déploiement :

- `screenshots/01_terraform_output.png` : `terraform output`
- `screenshots/02_aws_instances.png` : Instances AWS avec le tag td2-42
- `screenshots/03_ssh_bastion.png` : Connexion SSH au bastion
- `screenshots/04_ping_suricata.png` : Ping depuis le bastion vers la sonde (règle Suricata)
- `screenshots/05_ssh_sonde.png` : Connexion au sonde + vérification Suricata
- `screenshots/06_ssh_private.png` : Connexion à l'instance privée + test NAT

## Nettoyage

```bash
terraform destroy
```

## Notes

- Toutes les ressources portent le préfixe `td2-42-`
- La clé SSH utilisée est `td2-42-key`
- L'IP publique personnelle a été utilisée pour restreindre l'accès SSH au bastion
- Le projet utilise le VPC par défaut d'AWS dans la région eu-west-3

---

**Travail réalisé dans le cadre du TD2 Terraform - Filtrage et IDS Suricata**
