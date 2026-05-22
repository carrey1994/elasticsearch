package com.elasticsearch.demo.repository

import com.elasticsearch.demo.model.ProductDocument
import org.springframework.data.elasticsearch.repository.ElasticsearchRepository

interface ProductSearchRepository : ElasticsearchRepository<ProductDocument, Long>
