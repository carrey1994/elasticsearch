package com.elasticsearch.demo.service

import co.elastic.clients.elasticsearch._types.query_dsl.Query
import com.elasticsearch.demo.dto.CreateProductRequest
import com.elasticsearch.demo.dto.ProductResponse
import com.elasticsearch.demo.model.Product
import com.elasticsearch.demo.model.ProductDocument
import com.elasticsearch.demo.repository.ProductRepository
import com.elasticsearch.demo.repository.ProductSearchRepository
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.data.elasticsearch.client.elc.NativeQuery
import org.springframework.data.elasticsearch.core.ElasticsearchOperations
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
class ProductService(
	private val productRepository: ProductRepository,
	private val productSearchRepository: ProductSearchRepository,
	private val elasticsearchOperations: ElasticsearchOperations,
) {
	@Transactional
	fun create(request: CreateProductRequest): ProductResponse {
		val product =
			productRepository.save(
				Product(
					name = request.name.trim(),
					description = request.description.trim(),
					price = request.price,
				),
			)

		productSearchRepository.save(ProductDocument.from(product))
		return ProductResponse.from(product)
	}

	fun search(keyword: String): List<ProductResponse> {
		val trimmed = keyword.trim()
		if (trimmed.isEmpty()) {
			return emptyList()
		}

		val query =
			NativeQuery.builder()
				.withQuery(
					Query.of { q ->
						q.multiMatch { mm ->
							mm.query(trimmed)
							mm.fields("name", "description")
						}
					},
				)
				.build()

		val searchHits = elasticsearchOperations.search(query, ProductDocument::class.java)
		return searchHits.map { ProductResponse.from(it.content) }.toList()
	}

	fun page(keyword: String, pageable: Pageable): Page<ProductResponse> {
		return productSearchRepository.searchPageByName(keyword, pageable).map { ProductResponse.from(it) }
	}
}
