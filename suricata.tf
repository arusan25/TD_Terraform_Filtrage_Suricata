data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-22.04-amd64-server-*"]
  }
}

resource "aws_security_group" "sonde" {
  name        = "${local.prefix}sg-sonde"
  description = "Sonde Suricata - acces depuis bastion"
  vpc_id      = data.aws_vpc.default.id
  ingress {
    description     = "SSH depuis le bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
  ingress {
    description     = "ICMP depuis le bastion"
    from_port       = -1
    to_port         = -1
    protocol        = "icmp"
    security_groups = [aws_security_group.bastion.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${local.prefix}sg-sonde" }
}

resource "aws_instance" "sonde" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = data.aws_subnets.public_a.ids[0]
  vpc_security_group_ids      = [aws_security_group.sonde.id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  user_data                   = <<-EOT
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y software-properties-common
    add-apt-repository -y ppa:oisf/suricata-stable
    apt-get update -y
    apt-get install -y suricata
    # Detect AWS interface (ens5 or eth0)
    IFACE=$(ip -o -4 route show to default | awk '{print $5}' | head -1)
    if [ -n "$IFACE" ]; then
      sed -i "s/^\s*interface:\s*.*/  interface: $IFACE/" /etc/suricata/suricata.yaml || true
    fi
    # Add custom detection rule for TD2
    mkdir -p /var/lib/suricata/rules
    echo 'alert icmp any any -> any any (msg:"TD2 ICMP detecte"; sid:1000001; rev:1;)' >> /var/lib/suricata/rules/suricata.rules
    suricata-update || true
    systemctl enable suricata
    systemctl restart suricata
  EOT
  tags                        = { Name = "${local.prefix}sonde" }
}

output "sonde_private_ip" {
  value = aws_instance.sonde.private_ip
}

output "sonde_public_ip" {
  value = aws_instance.sonde.public_ip
}
