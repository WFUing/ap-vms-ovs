<?xml version="1.0" ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output omit-xml-declaration="yes" indent="yes"/>

  <!-- Identity template, copies everything as is -->
  <xsl:template match="node()|@*">
    <xsl:copy>
      <xsl:apply-templates select="node()|@*"/>
    </xsl:copy>
  </xsl:template>

  <!-- Template for modifying the DHCP range -->
  <xsl:template match="/network/ip/dhcp/range">
    <xsl:copy>
      <xsl:attribute name="start">
        <xsl:value-of select="$network_dhcp_range_start"/>
      </xsl:attribute>
      <xsl:attribute name="end">
        <xsl:value-of select="$network_dhcp_range_end"/>
      </xsl:attribute>
      <!-- Apply templates to other attributes and child nodes -->
      <xsl:apply-templates select="@*[not(local-name()='end') and not(local-name()='start')]|node()"/>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
