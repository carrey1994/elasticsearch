package com.elasticsearch.demo.service

import com.elasticsearch.demo.model.ProductDocument
import com.elasticsearch.demo.repository.ProductRepository
import com.elasticsearch.demo.repository.ProductSearchRepository
import org.slf4j.LoggerFactory
import org.springframework.data.elasticsearch.core.ElasticsearchOperations
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
class ProductElasticsearchSyncService(
	private val productRepository: ProductRepository,
	private val productSearchRepository: ProductSearchRepository,
	private val elasticsearchOperations: ElasticsearchOperations,
) {
	private val log = LoggerFactory.getLogger(javaClass)

	@Transactional(readOnly = true)
	fun reindexAll() {
		val indexOps = elasticsearchOperations.indexOps(ProductDocument::class.java)

		if (indexOps.exists()) {
			log.info("Deleting Elasticsearch index: products")
			indexOps.delete()
		}

		log.info("Creating Elasticsearch index: products")
		indexOps.createWithMapping()

		val products = productRepository.findAll()
		if (products.isEmpty()) {
			log.info("No products in database; Elasticsearch index is empty")
			return
		}

		val documents = products.map { ProductDocument.from(it) }
		productSearchRepository.saveAll(documents)
		log.info("Indexed {} product(s) from database into Elasticsearch", documents.size)
	}
}
