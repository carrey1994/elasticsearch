package com.elasticsearch.demo.config

import com.elasticsearch.demo.service.ProductElasticsearchSyncService
import org.springframework.boot.ApplicationArguments
import org.springframework.boot.ApplicationRunner
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.stereotype.Component

@Component
@ConditionalOnProperty(
	name = ["app.elasticsearch.reindex-on-startup"],
	havingValue = "true",
	matchIfMissing = true,
)
class ProductIndexStartupRunner(
	private val productElasticsearchSyncService: ProductElasticsearchSyncService,
) : ApplicationRunner {
	override fun run(args: ApplicationArguments) {
		productElasticsearchSyncService.reindexAll()
	}
}
