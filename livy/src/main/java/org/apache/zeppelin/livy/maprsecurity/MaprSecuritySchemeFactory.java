package org.apache.zeppelin.livy.maprsecurity;

import org.apache.hc.client5.http.auth.AuthScheme;
import org.apache.hc.client5.http.auth.AuthSchemeFactory;
import org.apache.hc.core5.http.protocol.HttpContext;


class MaprSecuritySchemeFactory implements AuthSchemeFactory {
  @Override
  public AuthScheme create(HttpContext context) {
    return new MaprSecurityScheme();
  }
}
