using System;
using Newtonsoft.Json;

namespace SSISApiIntegration
{
    /// <summary>
    /// Data Transfer Object representing an objection letter for API communication
    /// This class maps the SQL Server table fields to a structured object for JSON serialization
    /// </summary>
    public class ObjectionLetterDto
    {
        /// <summary>
        /// Identification number (IH_CRIBNR field)
        /// </summary>
        [JsonProperty("ih_cribnr")]
        public string IH_CRIBNR { get; set; }

        /// <summary>
        /// Date of the objection (Datum field)
        /// </summary>
        [JsonProperty("datum")]
        public DateTime Datum { get; set; }

        /// <summary>
        /// Subject or concerning information (Betreffende field)
        /// </summary>
        [JsonProperty("betreffende")]
        public string Betreffende { get; set; }

        /// <summary>
        /// Assessment number (Aanslagnummer field)
        /// </summary>
        [JsonProperty("aanslagnummer")]
        public string Aanslagnummer { get; set; }

        /// <summary>
        /// Description (BM_OMSCHRIJVING field)
        /// </summary>
        [JsonProperty("bm_omschrijving")]
        public string BM_OMSCHRIJVING { get; set; }

        /// <summary>
        /// Period information (Periode field)
        /// </summary>
        [JsonProperty("periode")]
        public string Periode { get; set; }

        /// <summary>
        /// Outstanding amount (OpenstandBedrag field)
        /// </summary>
        [JsonProperty("openstandBedrag")]
        public decimal OpenstandBedrag { get; set; }

        /// <summary>
        /// Disputed amount (BestredenBedrag field)
        /// </summary>
        [JsonProperty("bestredenBedrag")]
        public decimal BestredenBedrag { get; set; }

        /// <summary>
        /// Non-disputed amount (NietBestredenBedrag field)
        /// </summary>
        [JsonProperty("nietBestredenBedrag")]
        public decimal NietBestredenBedrag { get; set; }

        /// <summary>
        /// Costs (Kosten field)
        /// </summary>
        [JsonProperty("kosten")]
        public decimal Kosten { get; set; }

        /// <summary>
        /// Total outstanding amount (TotaalOpenstand field)
        /// </summary>
        [JsonProperty("totaalOpenstand")]
        public decimal TotaalOpenstand { get; set; }

        /// <summary>
        /// Special circumstances (UB_BIJZONDERHEDEN field)
        /// </summary>
        [JsonProperty("ub_bijzonderheden")]
        public string UB_BIJZONDERHEDEN { get; set; }

        /// <summary>
        /// Special remarks (RU_BIJZONDER field)
        /// </summary>
        [JsonProperty("ru_bijzonder")]
        public string RU_BIJZONDER { get; set; }

        /// <summary>
        /// Unique identifier (UB_ID field)
        /// </summary>
        [JsonProperty("ub_id")]
        public int UB_ID { get; set; }

        /// <summary>
        /// Processing date (UB_DATUM field)
        /// </summary>
        [JsonProperty("ub_datum")]
        public DateTime UB_DATUM { get; set; }

        /// <summary>
        /// Converts the ObjectionLetterDto to JSON string
        /// </summary>
        /// <returns>JSON representation of the object</returns>
        public string ToJson()
        {
            return JsonConvert.SerializeObject(this, Formatting.None);
        }

        /// <summary>
        /// Validates the ObjectionLetterDto for required fields
        /// </summary>
        /// <returns>True if valid, false otherwise</returns>
        public bool IsValid()
        {
            return !string.IsNullOrEmpty(IH_CRIBNR) && 
                   !string.IsNullOrEmpty(Aanslagnummer) && 
                   UB_ID > 0;
        }
    }
}