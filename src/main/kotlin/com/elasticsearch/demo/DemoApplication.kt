package com.elasticsearch.demo

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication
import org.springframework.data.elasticsearch.repository.config.EnableElasticsearchRepositories

@SpringBootApplication
@EnableElasticsearchRepositories(
	basePackages = ["com.elasticsearch.demo.repository"]
)
class DemoApplication

fun main(args: Array<String>) {
	runApplication<DemoApplication>(*args)
}
