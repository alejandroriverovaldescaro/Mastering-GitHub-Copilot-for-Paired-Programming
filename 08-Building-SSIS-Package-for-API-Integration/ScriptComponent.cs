using System;
using System.Data;
using Microsoft.SqlServer.Dts.Pipeline.Wrapper;
using Microsoft.SqlServer.Dts.Runtime.Wrapper;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;

/// <summary>
/// SSIS Script Component for API Integration with Basic Authentication
/// This script component transforms each row into JSON and posts it to a REST API endpoint
/// Compatible with SQL Server 2012 and Visual Studio 2017 SSDT
/// </summary>
[Microsoft.SqlServer.Dts.Pipeline.SSISScriptComponentEntryPointAttribute]
public class ScriptMain : UserComponent
{
    private static readonly HttpClient httpClient = new HttpClient();
    private string apiEndpoint;
    private string apiUsername;
    private string apiPassword;
    private string basicAuthHeader;

    /// <summary>
    /// Initialize the script component
    /// Setup HTTP client and authentication
    /// </summary>
    public override void PreExecute()
    {
        base.PreExecute();
        
        try
        {
            // Get SSIS variables for API configuration
            apiEndpoint = Variables.ApiEndpoint.ToString();
            apiUsername = Variables.ApiUsername.ToString();
            apiPassword = Variables.ApiPassword.ToString();
            
            // Create Basic Authentication header
            string credentials = Convert.ToBase64String(Encoding.ASCII.GetBytes($"{apiUsername}:{apiPassword}"));
            basicAuthHeader = $"Basic {credentials}";
            
            // Configure HTTP client
            httpClient.DefaultRequestHeaders.Clear();
            httpClient.DefaultRequestHeaders.Add("Authorization", basicAuthHeader);
            httpClient.DefaultRequestHeaders.Add("Content-Type", "application/json");
            httpClient.Timeout = TimeSpan.FromSeconds(30);
            
            // Log initialization
            bool fireAgain = false;
            ComponentMetaData.FireInformation(0, "ScriptComponent", "API integration initialized successfully", "", 0, ref fireAgain);
        }
        catch (Exception ex)
        {
            bool fireAgain = false;
            ComponentMetaData.FireError(0, "ScriptComponent", $"Error in PreExecute: {ex.Message}", "", 0, out fireAgain);
            throw;
        }
    }

    /// <summary>
    /// Process each input row
    /// Transform row data to ObjectionLetterDto and post to API
    /// </summary>
    /// <param name="Row">Input row from SQL Server</param>
    public override void Input0_ProcessInputRow(Input0Buffer Row)
    {
        try
        {
            // Create ObjectionLetterDto from row data
            var objectionLetter = new ObjectionLetterDto
            {
                UB_ID = Row.UBID,
                IH_CRIBNR = Row.IHCRIBNR_IsNull ? string.Empty : Row.IHCRIBNR,
                Datum = Row.Datum_IsNull ? DateTime.MinValue : Row.Datum,
                Betreffende = Row.Betreffende_IsNull ? string.Empty : Row.Betreffende,
                Aanslagnummer = Row.Aanslagnummer_IsNull ? string.Empty : Row.Aanslagnummer,
                BM_OMSCHRIJVING = Row.BMOMSCHRIJVING_IsNull ? string.Empty : Row.BMOMSCHRIJVING,
                Periode = Row.Periode_IsNull ? string.Empty : Row.Periode,
                OpenstandBedrag = Row.OpenstandBedrag_IsNull ? 0 : Row.OpenstandBedrag,
                BestredenBedrag = Row.BestredenBedrag_IsNull ? 0 : Row.BestredenBedrag,
                NietBestredenBedrag = Row.NietBestredenBedrag_IsNull ? 0 : Row.NietBestredenBedrag,
                Kosten = Row.Kosten_IsNull ? 0 : Row.Kosten,
                TotaalOpenstand = Row.TotaalOpenstand_IsNull ? 0 : Row.TotaalOpenstand,
                UB_BIJZONDERHEDEN = Row.UBBIJZONDERHEDEN_IsNull ? string.Empty : Row.UBBIJZONDERHEDEN,
                RU_BIJZONDER = Row.RUBIJZONDER_IsNull ? string.Empty : Row.RUBIJZONDER,
                UB_DATUM = Row.UBDATUM_IsNull ? DateTime.MinValue : Row.UBDATUM
            };

            // Validate the objection letter data
            if (!objectionLetter.IsValid())
            {
                // Send to error output
                ErrorOutput0Buffer.AddRow();
                ErrorOutput0Buffer.UBID = Row.UBID;
                ErrorOutput0Buffer.ErrorDescription = "Invalid objection letter data - missing required fields";
                return;
            }

            // Post to API
            bool success = PostToApiAsync(objectionLetter).GetAwaiter().GetResult();
            
            if (success)
            {
                // Send to success output
                SuccessOutput0Buffer.AddRow();
                SuccessOutput0Buffer.UBID = Row.UBID;
                SuccessOutput0Buffer.ProcessedDateTime = DateTime.Now;
                SuccessOutput0Buffer.ApiResponse = "Success";
            }
            else
            {
                // Send to error output
                ErrorOutput0Buffer.AddRow();
                ErrorOutput0Buffer.UBID = Row.UBID;
                ErrorOutput0Buffer.ErrorDescription = "API call failed";
            }
        }
        catch (Exception ex)
        {
            // Send to error output
            ErrorOutput0Buffer.AddRow();
            ErrorOutput0Buffer.UBID = Row.UBID;
            ErrorOutput0Buffer.ErrorDescription = $"Processing error: {ex.Message}";
            
            bool fireAgain = false;
            ComponentMetaData.FireError(0, "ScriptComponent", $"Error processing row {Row.UBID}: {ex.Message}", "", 0, out fireAgain);
        }
    }

    /// <summary>
    /// Post ObjectionLetterDto to API endpoint
    /// </summary>
    /// <param name="objectionLetter">The objection letter data to post</param>
    /// <returns>True if successful, false otherwise</returns>
    private async Task<bool> PostToApiAsync(ObjectionLetterDto objectionLetter)
    {
        try
        {
            // Serialize to JSON
            string jsonContent = objectionLetter.ToJson();
            
            // Create HTTP content
            var content = new StringContent(jsonContent, Encoding.UTF8, "application/json");
            
            // Make API call
            HttpResponseMessage response = await httpClient.PostAsync(apiEndpoint, content);
            
            // Log the request
            bool fireAgain = false;
            ComponentMetaData.FireInformation(0, "ScriptComponent", 
                $"API call for UB_ID {objectionLetter.UB_ID}: {response.StatusCode}", "", 0, ref fireAgain);
            
            // Check if successful
            if (response.IsSuccessStatusCode)
            {
                string responseContent = await response.Content.ReadAsStringAsync();
                ComponentMetaData.FireInformation(0, "ScriptComponent", 
                    $"API Success for UB_ID {objectionLetter.UB_ID}: {responseContent}", "", 0, ref fireAgain);
                return true;
            }
            else
            {
                string errorContent = await response.Content.ReadAsStringAsync();
                ComponentMetaData.FireWarning(0, "ScriptComponent", 
                    $"API Error for UB_ID {objectionLetter.UB_ID}: {response.StatusCode} - {errorContent}", "", 0);
                return false;
            }
        }
        catch (HttpRequestException httpEx)
        {
            bool fireAgain = false;
            ComponentMetaData.FireError(0, "ScriptComponent", 
                $"HTTP Error for UB_ID {objectionLetter.UB_ID}: {httpEx.Message}", "", 0, out fireAgain);
            return false;
        }
        catch (TaskCanceledException timeoutEx)
        {
            bool fireAgain = false;
            ComponentMetaData.FireError(0, "ScriptComponent", 
                $"Timeout Error for UB_ID {objectionLetter.UB_ID}: {timeoutEx.Message}", "", 0, out fireAgain);
            return false;
        }
        catch (Exception ex)
        {
            bool fireAgain = false;
            ComponentMetaData.FireError(0, "ScriptComponent", 
                $"Unexpected Error for UB_ID {objectionLetter.UB_ID}: {ex.Message}", "", 0, out fireAgain);
            return false;
        }
    }

    /// <summary>
    /// Cleanup resources
    /// </summary>
    public override void PostExecute()
    {
        base.PostExecute();
        
        try
        {
            httpClient?.Dispose();
            
            bool fireAgain = false;
            ComponentMetaData.FireInformation(0, "ScriptComponent", "API integration completed successfully", "", 0, ref fireAgain);
        }
        catch (Exception ex)
        {
            bool fireAgain = false;
            ComponentMetaData.FireError(0, "ScriptComponent", $"Error in PostExecute: {ex.Message}", "", 0, out fireAgain);
        }
    }
}

/// <summary>
/// ObjectionLetterDto class embedded in script component
/// </summary>
public class ObjectionLetterDto
{
    [JsonProperty("ub_id")]
    public int UB_ID { get; set; }

    [JsonProperty("ih_cribnr")]
    public string IH_CRIBNR { get; set; }

    [JsonProperty("datum")]
    public DateTime Datum { get; set; }

    [JsonProperty("betreffende")]
    public string Betreffende { get; set; }

    [JsonProperty("aanslagnummer")]
    public string Aanslagnummer { get; set; }

    [JsonProperty("bm_omschrijving")]
    public string BM_OMSCHRIJVING { get; set; }

    [JsonProperty("periode")]
    public string Periode { get; set; }

    [JsonProperty("openstandBedrag")]
    public decimal OpenstandBedrag { get; set; }

    [JsonProperty("bestredenBedrag")]
    public decimal BestredenBedrag { get; set; }

    [JsonProperty("nietBestredenBedrag")]
    public decimal NietBestredenBedrag { get; set; }

    [JsonProperty("kosten")]
    public decimal Kosten { get; set; }

    [JsonProperty("totaalOpenstand")]
    public decimal TotaalOpenstand { get; set; }

    [JsonProperty("ub_bijzonderheden")]
    public string UB_BIJZONDERHEDEN { get; set; }

    [JsonProperty("ru_bijzonder")]
    public string RU_BIJZONDER { get; set; }

    [JsonProperty("ub_datum")]
    public DateTime UB_DATUM { get; set; }

    public string ToJson()
    {
        return JsonConvert.SerializeObject(this, Formatting.None);
    }

    public bool IsValid()
    {
        return !string.IsNullOrEmpty(IH_CRIBNR) && 
               !string.IsNullOrEmpty(Aanslagnummer) && 
               UB_ID > 0;
    }
}