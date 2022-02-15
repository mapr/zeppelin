package org.apache.zeppelin.livy.maprsecurity;

import org.apache.http.auth.AuthSchemeProvider;
import org.apache.http.auth.AuthScope;
import org.apache.http.auth.Credentials;
import org.apache.http.client.HttpClient;
import org.apache.http.client.config.RequestConfig;
import org.apache.http.config.Lookup;
import org.apache.http.config.RegistryBuilder;
import org.apache.http.impl.client.BasicCredentialsProvider;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClientBuilder;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.client.HttpComponentsClientHttpRequestFactory;
import org.springframework.web.client.RestTemplate;

import java.security.Principal;
import java.util.Arrays;
import java.util.Collections;

public class MaprSecurityRestTemplate extends RestTemplate {

  private static final Logger logger = LoggerFactory.getLogger(MaprSecurityRestTemplate.class);

  private static final Credentials credentials = new MaprSecurityRestTemplate.NullCredentials();

  public MaprSecurityRestTemplate() {
    this(buildHttpClient());
  }

  public MaprSecurityRestTemplate(HttpClient httpClient) {
    super(new HttpComponentsClientHttpRequestFactory(httpClient));
  }

  private static HttpClient buildHttpClient() {
    HttpClientBuilder builder = HttpClientBuilder.create();

    builder = configureHttpClientBuilder(builder);

    CloseableHttpClient httpClient = builder.build();
    return httpClient;
  }

  public static HttpClientBuilder configureHttpClientBuilder(HttpClientBuilder builder) {
    logger.info("Creating custom MapR Rest template");
    Lookup<AuthSchemeProvider> authSchemeRegistry = RegistryBuilder.<AuthSchemeProvider> create()
            .register(MaprSecurityScheme.NAME, new MaprSecuritySchemeFactory()).build();
    builder.setDefaultAuthSchemeRegistry(authSchemeRegistry);

    RequestConfig.Builder rc = RequestConfig.custom();
    rc.setTargetPreferredAuthSchemes(
            Collections.unmodifiableList(Arrays.asList(MaprSecurityScheme.NAME)));
    builder.setDefaultRequestConfig(rc.build());

    BasicCredentialsProvider credentialsProvider = new BasicCredentialsProvider();
    credentialsProvider.setCredentials(new AuthScope(null, -1, null), credentials);
    builder.setDefaultCredentialsProvider(credentialsProvider);

    return builder;
  }

  private static class NullCredentials implements Credentials {

    @Override
    public Principal getUserPrincipal() {
      return null;
    }

    @Override
    public String getPassword() {
      return null;
    }

  }

}
