import * as cdk from "aws-cdk-lib"
import * as ecs from "aws-cdk-lib/aws-ecs"
import { Construct } from "constructs"
import { IpAddresses, Vpc } from "aws-cdk-lib/aws-ec2"
import { ApplicationLoadBalancedFargateService } from "aws-cdk-lib/aws-ecs-patterns"
import { ApplicationProtocol } from "aws-cdk-lib/aws-elasticloadbalancingv2"
 
export class InfrastructureStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props)
    const vpc = new Vpc(this, `${id}-vpc`, {
      vpcName: `${id}-vpc`,
      ipAddresses: IpAddresses.cidr("10.0.0.0/16"),
      maxAzs: 2,
    })
 
    const cluster = new ecs.Cluster(this, `${id}-cluster`, {
      clusterName: `${id}-cluster`,
      vpc,
    })
 
    const fargateService = new ApplicationLoadBalancedFargateService(
      this,
      `${id}-fargate`,
      {
        serviceName: `${id}-fargate-service`,
        loadBalancerName: `${id}-fargate-lba`,
        cluster,
        cpu: 512,
        memoryLimitMiB: 1024,
        protocol: ApplicationProtocol.HTTP,
        desiredCount: 1,
        publicLoadBalancer: true,
        taskImageOptions: {
          image: ecs.ContainerImage.fromAsset("../next-app"),
          containerName: `${id}-container`,
          containerPort: 3000,
        },
      }
    )
 
    // Output the load balancer URL
    new cdk.CfnOutput(this, `${id}-url`, {
      value: fargateService.loadBalancer.loadBalancerDnsName,
    })
  }
}